
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

    private Gee.Set<DataPlugin> plugins;
    private Gee.List<Cancellable> cancellables;

    construct
    {
      plugins = new Gee.HashSet<DataPlugin> ();
      cancellables = new Gee.ArrayList<Cancellable> ();

      load_plugins ();
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

    // FIXME: public? really?
    public void register_plugin (DataPlugin plugin)
    {
      plugins.add (plugin);
    }

    private void load_plugins ()
    {
      // FIXME!
      register_plugin (new DesktopFilePlugin ());
      register_plugin (new ZeitgeistPlugin ());
      register_plugin (new HybridSearchPlugin ());
    }

    public void cancel_search ()
    {
      foreach (var c in cancellables) c.cancel ();
    }

    public async Gee.List<Match> search (string query,
                                         QueryFlags flags) throws SearchError
    {
      var q = Query (query, flags);

      // clear current cancellables
      cancellables.clear ();

      var current_result_set = new ResultSet ();
      int search_size = plugins.size;
      bool waiting = false;
      var current_cancellable = new Cancellable ();
      cancellables.add (current_cancellable);

      foreach (var data_plugin in plugins)
      {
        // we need to pass separate cancellable to each plugin, because we're
        // running them in parallel
        var c = new Cancellable ();
        cancellables.add (c);
        q.cancellable = c;
        // magic comes here
        data_plugin.search.begin (q, (src_obj, res) =>
        {
          var plugin = src_obj as DataPlugin;
          try
          {
            var results = plugin.search.end (res);
            current_result_set.add_all (results);
          }
          catch (SearchError err)
          {
            if (!(err is SearchError.SEARCH_CANCELLED))
            {
              warning ("%s returned error: %s",
                       plugin.get_type ().name (), err.message);
            }
          }

          if (--search_size == 0 && waiting) search.callback ();
        });
      }

      waiting = true;
      if (search_size > 0) yield;

      if (current_cancellable.is_cancelled ())
      {
        throw new SearchError.SEARCH_CANCELLED ("Cancelled");
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
    warning ("Enter search string as command line argument!");
  }
  else
  {
    var loop = new MainLoop ();
    var sink = Sezen.DataSink.get_default ();
    string query = argv[1];
    debug (@"Searching for $query");
    sink.search (query);

    loop.run ();
  }

  return 0;
}
#endif
