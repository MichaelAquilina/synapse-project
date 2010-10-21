
namespace Sezen
{
  public class HybridSearchPlugin: DataPlugin
  {
    private class MatchObject: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }

      private string uri;

      public void execute ()
      {
        var f = File.new_for_uri (uri);
        var app_info = f.query_default_handler (null);
        List<File> files = new List<File> ();
        files.prepend (f);
        app_info.launch (files, new Gdk.AppLaunchContext ());
      }

      public MatchObject (string? thumbnail_path, string? icon)
      {
        Object (has_thumbnail: thumbnail_path != null,
                icon_name: icon ?? "",
                thumbnail_path: thumbnail_path ?? "");
      }
    }

    construct
    {
    }

    private string interesting_attributes =
      string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                        FILE_ATTRIBUTE_STANDARD_ICON,
                        FILE_ATTRIBUTE_THUMBNAIL_PATH,
                        null);

    public override async ResultSet? search (Query q) throws SearchError
    {
      var result = new ResultSet ();

      // processing code here

      if (q.is_cancelled ())
      {
        throw new SearchError.SEARCH_CANCELLED ("Cancelled");
      }

      return result;
    }
  }
}
