
#if CMD_LINE_UI
int main (string[] argv)
{
  if (argv.length <= 1)
  {
    print ("Enter search string as command line argument!\n");
  }
  else
  {
    var loop = new MainLoop ();
    var sink = Sezen.DataSink.get_default ();
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
