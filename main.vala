
namespace Sezen
{
  public interface Match: Object
  {
    // properties
    public abstract string title { get; construct set; }
    public abstract string description { get; set; }
    public abstract string icon_name { get; construct set; }
    public abstract bool has_thumbnail { get; construct set; }
    public abstract string thumbnail_path { get; construct set; }

    public abstract void execute ();
  }

  public class ResultSet : Object, Gee.Iterable <Gee.Map.Entry <Match, int>>
  {
    protected Gee.Map<Match, int> matches;

    public ResultSet ()
    {
      Object ();
    }

    construct
    {
      matches = new Gee.HashMap<Match, int> ();
    }

    public Type element_type { get { return matches.element_type; } }

    public Gee.Iterator<Gee.Map.Entry <Match, int>?> iterator ()
    {
      return matches.iterator ();
    }

    public void add (Match match, int relevancy)
    {
      matches.set (match, relevancy);
    }

    public void add_all (ResultSet rs)
    {
      matches.set_all (rs.matches);
    }

    public Gee.List<Match> get_sorted_list ()
    {
      var l = new Gee.ArrayList<Gee.Map.Entry<Match, int>> ();
      l.add_all (matches.entries);

      l.sort ((a, b) => 
      {
        unowned Gee.Map.Entry<Match, int> e1 = (Gee.Map.Entry<Match, int>) a;
        unowned Gee.Map.Entry<Match, int> e2 = (Gee.Map.Entry<Match, int>) b;
        int relevancy_delta = e2.value - e1.value;
        if (relevancy_delta != 0) return relevancy_delta;
        // FIXME: utf8 compare!
        else return e1.key.title.ascii_casecmp (e2.key.title);
      });

      var sorted_list = new Gee.ArrayList<Match> ();
      foreach (Gee.Map.Entry<Match, int> m in l)
      {
        sorted_list.add (m.key);
      }

      return sorted_list;
    }
  }

  errordomain SearchError
  {
    SEARCH_CANCELLED,
    UNKNOWN_ERROR
  }

  public abstract class DataPlugin : Object
  {
    public abstract async ResultSet? search (Query query) throws SearchError;
  }

  [Flags]
  public enum QueryFlags
  {
    LOCAL_ONLY    = 1 << 0,

    APPLICATIONS  = 1 << 1,
    ACTIONS       = 1 << 2,
    AUDIO         = 1 << 3,
    VIDEO         = 1 << 4,
    DOCUMENTS     = 1 << 5,
    IMAGES        = 1 << 6,
    INTERNET      = 1 << 7,

    UNCATEGORIZED = 1 << 15,

    LOCAL_CONTENT = 0xFF | QueryFlags.UNCATEGORIZED,
    ALL           = 0xFE | QueryFlags.UNCATEGORIZED
  }

  public struct Query
  {
    string query_string;
    string query_string_folded;
    Cancellable cancellable;
    QueryFlags query_type;

    public Query (string query, QueryFlags flags = QueryFlags.LOCAL_CONTENT)
    {
      this.query_string = query;
      this.query_string_folded = query.casefold ();
      this.query_type = flags;
    }

    public bool is_cancelled ()
    {
      return cancellable.is_cancelled ();
    }
  }

  public class DataSink : Object
  {
    private DataSink ()
    {
    }

    construct
    {
      enumerate_plugins ();
    }

    private static DataSink? instance = null;
    public static unowned DataSink get_default ()
    {
      if (instance == null)
      {
        instance = new DataSink ();
      }
      return instance;
    }

    private Gee.Set<DataPlugin> plugins = new Gee.HashSet<DataPlugin> ();

    // FIXME: public? really?
    public void register_plugin (DataPlugin plugin)
    {
      plugins.add (plugin);
    }

    private void enumerate_plugins ()
    {
      // FIXME!
      register_plugin (new DesktopFilePlugin ());
      register_plugin (new ZeitgeistPlugin ());
    }

    public signal void search_complete ();

    private void search_done (Object? obj, AsyncResult res)
    {
      // FIXME: process results from all plugins
      var plugin = obj as DataPlugin;
      debug ("%s finished search", plugin.get_type ().name ());
      try
      {
        var results = plugin.search.end (res);
        current_result_set.add_all (results);
      }
      catch (SearchError err)
      {
        warning ("%s returned error: %s",
                 plugin.get_type ().name (), err.message);
      }

      if (--search_size == 0)
      {
        search_complete ();
      }
    }

    private ResultSet current_result_set;
    private int search_size;

    public async Gee.List<Match> search (string query)
    {
      var q = Query (query);

      current_result_set = new ResultSet ();
      search_size = plugins.size;

      foreach (var plugin in plugins)
      {
        // we need to pass separate cancellable to each plugin
        var c = new Cancellable ();
        q.cancellable = c;
        plugin.search (q, search_done);
      }

      if (search_size > 0)
      {
        ulong sig_id = this.search_complete.connect (() =>
          { search.callback (); }
        );
        yield;
        SignalHandler.disconnect (this, sig_id);
      }

      return current_result_set.get_sorted_list ();
    }
  }
}

#if CMD_LINE_UI
int main (string[] argv)
{
  if (argv.length <= 1)
  {
    warning ("We need more params...");
  }
  else
  {
    var loop = new MainLoop ();
    var sink = Sezen.DataSink.get_default ();
    string query = argv[1];
    debug (@"Searching for $query");
    sink.search (query);
    //sink.search_complete.connect (() => { loop.quit (); });

    loop.run ();
  }

  return 0;
}
#endif
