/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

namespace Synapse
{
  public class OpenWithActions: ActionPlugin
  {
    private abstract class Action: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public string uri { get; set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; }

      public abstract void execute_internal (Match? match);
      public void execute (Match? match)
      {
        execute_internal (match);
      }
    }

    private class Opener: Action
    {
      private AppInfo info;
      public Opener (AppInfo info)
      {
        Object (title: "",
                description: "",
                icon_name: "", has_thumbnail: false,
                match_type: MatchType.ACTION);
        this.info = info;
        this.title = "Open with %s".printf(info.get_display_name ());
        this.description = info.get_description ();
        if (this.description == null)
          this.description = "";
        Icon? ico = info.get_icon ();
        if (ico != null)
          this.icon_name = ico.to_string ();
        else
          this.icon_name = "";
      }

      public override void execute_internal (Match? match)
      {
        var f = File.new_for_uri (match.uri);
        try
        {
          List<File> files = new List<File> ();
          files.prepend (f);
          info.launch (files, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
    }
    
    private string[] mimetypes_path;
    private Gee.Map<string, Gee.List<AppInfo>> assoc;
    construct
    {
      mimetypes_path = {
        Environment.get_home_dir ()+"/mime.types",
        "/etc/mime.types",
        "/usr/etc/mime.types",
        "/usr/local/etc/mime.types"
        //FIXME: add a Synapse-made-in mime.types file
      };
      assoc = new Gee.HashMap<string, Gee.List<AppInfo>> ();
      init_mimetypes ();
    }
    private void init_mimetypes ()
    {
      for (int i = 0; i < mimetypes_path.length; i++)
        init_mimetypes_from_file (mimetypes_path[i]);
    }
    private void init_mimetypes_from_file (string path)
    {
      debug ("Try to get mime types from: %s", path);
      // A reference to our file
      var file = File.new_for_path (path);

      if (!file.query_exists ()) {
          return;
      }

      try {
          // Open file for reading and wrap returned FileInputStream into a
          // DataInputStream, so we can read line by line
          var dis = new DataInputStream (file.read ());
          string line;
          // prepare regexps
          var regex = new Regex ("^[\\s]*([[:alnum:]\\-]*/[[:alnum:]\\-]*)", RegexCompileFlags.OPTIMIZE);
          
          // Read lines until end of file (null) is reached
          MatchInfo minfo;
          string mt = "";
          while ((line = dis.read_line (null)) != null) {
              if (!regex.match (line, 0, out minfo))
                continue;
              mt = minfo.fetch (1);
              if (!assoc.contains (mt))
              {
                init_mime_type (mt);
              }
          }
      } catch (Error e) {
          debug ("Cannot read %s", path);
      }
    }
    private async void init_mime_type_async (string mt)
    {
      init_mime_type (mt);
    }
    private void init_mime_type (string mt)
    {
      //initialize mimetype!
      GLib.List<AppInfo>? list = AppInfo.get_all_for_type (mt);
      Gee.List<AppInfo> geelist = new Gee.ArrayList<AppInfo>();
      if (list != null)
      {
        foreach (AppInfo info in list)
        {
          geelist.add (info);
        }
      }
      assoc.set (mt, geelist);
    }
    public override bool handles_unknown ()
    {
      return false;
    }

    public override ResultSet? find_for_match (Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();
      /* We want only files */
      if (match.match_type != MatchType.GENERIC_URI)
        return results;
      UriMatch uri = (UriMatch) match;
      string mt = uri.mime_type;
      /* get the mime type openers */
      if (!assoc.contains (mt))
      {
        // we don't have that mime type, strange!
        // so init for the next time! (async?! for now yes)
        init_mime_type_async (mt);
      }
      Gee.List<AppInfo> openers = assoc.get (mt);

      if (query_empty)
      {
        foreach (AppInfo info in openers)
        {
          results.add (new Opener (info), 80);
        }
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var info in openers)
        {
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (info.get_display_name()))
            {
              results.add (new Opener (info), 80);
              break;
            }
          }
        }
      }
      return results;
    }
  }
}
