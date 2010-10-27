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
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Sezen
{
  public class CommonActions: ActionPlugin
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
      
      public abstract bool valid_for_match (Match match);
    }
    
    private class Runner: Action
    {
      public Runner ()
      {
        Object (title: "Run", // FIXME: i18n
                icon_name: "system-run", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 100);
      }

      public void execute (Match? match)
      {
        if (match.match_type == MatchType.DESKTOP_ENTRY)
        {
          var de = new DesktopAppInfo.from_filename (match.uri);
          try
          {
            de.launch (null, new Gdk.AppLaunchContext ());
          }
          catch (Error err)
          {
            warning ("%s", err.message);
          }
        }
        else // MatchType.ACTION
        {
          match.execute (null);
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.ACTION:
          case MatchType.DESKTOP_ENTRY:
            return true;
          default:
            return false;
        }
      }
    }
    
    private class Opener: Action
    {
      public Opener ()
      {
        Object (title: "Open", // FIXME: i18n
                icon_name: "fileopen", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 100);
      }

      public void execute (Match? match)
      {
        var f = File.new_for_uri (match.uri);
        var app_info = f.query_default_handler (null);
        List<File> files = new List<File> ();
        files.prepend (f);
        app_info.launch (files, new Gdk.AppLaunchContext ());
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            return true;
          default:
            return false;
        }
      }
    }

    private class OpenFolder: Action
    {
      public OpenFolder ()
      {
        Object (title: "Open folder", // FIXME: i18n
                icon_name: "folder-open", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 70);
      }

      public void execute (Match? match)
      {
        var f = File.new_for_uri (match.uri);
        f = f.get_parent ();
        var app_info = f.query_default_handler (null);
        List<File> files = new List<File> ();
        files.prepend (f);
        app_info.launch (files, new Gdk.AppLaunchContext ());
      }

      public override bool valid_for_match (Match match)
      {
        if (match.match_type != MatchType.GENERIC_URI) return false;
        var f = File.new_for_uri (match.uri);
        var parent = f.get_parent ();
        return parent != null && f.is_native ();
      }
    }
    
    private Gee.List<Action> actions;

    construct
    {
      actions = new Gee.ArrayList<Action> ();
      
      actions.add (new Runner ());
      actions.add (new Opener ());
      actions.add (new OpenFolder ());
    }

    public override ResultSet find_for_match (Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();
      
      if (query_empty)
      {
        foreach (var action in actions)
        {
          if (action.valid_for_match (match))
          {
            results.add (action, action.default_relevancy);
          }
        }
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var action in actions)
        {
          if (!action.valid_for_match (match)) continue;
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (action.title))
            {
              results.add (action, matcher.value);
              break;
            }
          }
        }
      }
      
      return results;
    }
  }
}
