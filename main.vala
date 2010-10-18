
namespace Sezen
{
  public interface Match: Object
  {
    // properties
    public abstract string title { get; construct set; }
    public abstract string description { get; set; }
    public abstract string icon_name { get; construct set; }
    public abstract bool has_thumbnail { get; construct set; }

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
        return e1.value - e2.value;
      });

      var sorted_list = new Gee.ArrayList<Match> ();
      foreach (Gee.Map.Entry<Match, int> m in l)
      {
        sorted_list.add (m.key);
      }

      return sorted_list;
    }
  }

  public abstract class DataPlugin : Object
  {
    public abstract async ResultSet? search (Query query);
  }

  public struct Query
  {
    string query_string;
    string query_string_folded;
    Cancellable cancellable;
    // TODO: subtype.. etc

    public Query (string query)
    {
      this.query_string = query;
      this.query_string_folded = query.casefold ();
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
    }

    private void search_done (Object? obj, AsyncResult res)
    {
      debug ("search finished");
      var plugin = obj as DataPlugin;
      var results = plugin.search.end (res);
      foreach (var match in results.get_sorted_list ())
      {
        debug ("found match: %s (%s)", match.title, 
                                       match.description);
      }
    }

    public async void search (string query)
    {
      var q = Query (query);
      foreach (var plugin in plugins)
      {
        // we should pass separate cancellable to each plugin
        var c = new Cancellable ();
        q.cancellable = c;
        plugin.search (q, search_done);
      }
    }
  }
}

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

    loop.run ();
  }

  return 0;
}
