
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
    public abstract string uri { get; set; }

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

    public Type element_type
    {
      get { return matches.element_type; }
    }
    public int size
    {
      get { return matches.size; }
    }
    public Gee.Set<Match> keys
    {
      owned get { return matches.keys; }
    }
    public Gee.Set<Gee.Map.Entry <Match, int>> entries
    {
      owned get { return matches.entries; }
    }

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
    public unowned DataSink data_sink { get; construct; }

    public abstract async ResultSet? search (Query query) throws SearchError;
  }

  public class DataSink : Object
  {
    public DataSink ()
    {
    }

    ~DataSink ()
    {
      debug ("DataSink died...");
    }

    private Gee.Set<DataPlugin> plugins;
    private Gee.List<Cancellable> cancellables;

    construct
    {
      plugins = new Gee.HashSet<DataPlugin> ();
      cancellables = new Gee.ArrayList<Cancellable> ();

      load_plugins ();
    }

    // FIXME: public? really?
    public void register_plugin (DataPlugin plugin)
    {
      plugins.add (plugin);
    }

    private void load_plugins ()
    {
      // FIXME: turn into proper modules
      register_plugin (Object.new (typeof (DesktopFilePlugin),
                       "data-sink", this, null) as DataPlugin);
      register_plugin (Object.new (typeof (ZeitgeistPlugin),
                       "data-sink", this, null) as DataPlugin);
      register_plugin (Object.new (typeof (HybridSearchPlugin),
                       "data-sink", this, null) as DataPlugin);
    }

    public signal void plugin_search_done (DataPlugin plugin, ResultSet rs);

    public void cancel_search ()
    {
      foreach (var c in cancellables) c.cancel ();
      cancellables.clear ();
    }

    public async Gee.List<Match> search (string query,
                                         QueryFlags flags) throws SearchError
    {
      var q = Query (query, flags);

      // clear current cancellables
      cancellables.clear (); // FIXME: really?

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
            plugin_search_done (plugin, results);
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

