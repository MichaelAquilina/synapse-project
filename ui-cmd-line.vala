
#if CMD_LINE_UI

MainLoop loop;

int main (string[] argv)
{
  if (argv.length <= 1)
  {
    print ("Enter search string as command line argument!\n");
  }
  else
  {
    loop = new MainLoop ();
    var sink = new Sezen.DataSink ();
    string query = argv[1];
    debug (@"Searching for $query");
    sink.search (query, Sezen.QueryFlags.LOCAL_CONTENT, (obj, res) =>
    {
      try
      {
        var rs = sink.search.end (res);
        foreach (var match in rs) debug ("%s", match.title);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      loop.quit ();
    });

    loop.run ();
  }

  return 0;
}
#endif
