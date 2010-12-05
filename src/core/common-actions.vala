/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
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
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; }
      
      public abstract bool valid_for_match (Match match);
      // stupid Vala...
      public abstract void execute_internal (Match? match);
      public void execute (Match? match)
      {
        execute_internal (match);
      }
    }
    
    private class Runner: Action
    {
      public Runner ()
      {
        Object (title: _ ("Run"),
                description: _ ("Run an application, action or script"),
                icon_name: "system-run", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 100);
      }

      public override void execute_internal (Match? match)
      {
        if (match.match_type == MatchType.APPLICATION)
        {
          ApplicationMatch? app_match = match as ApplicationMatch;
          return_if_fail (app_match != null);

          AppInfo app = app_match.app_info ??
            new DesktopAppInfo.from_filename (app_match.filename);

          try
          {
            app.launch (null, new Gdk.AppLaunchContext ());
            
            RelevancyService.get_default ().application_launched (app);
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
            return true;
          case MatchType.APPLICATION:
            ApplicationMatch? am = match as ApplicationMatch;
            return am == null || !am.needs_terminal;
          default:
            return false;
        }
      }
    }

    private class TerminalRunner: Action
    {
      public TerminalRunner ()
      {
        Object (title: _ ("Run in Terminal"),
                description: _ ("Run application or command in terminal"),
                icon_name: "terminal", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 60);
      }

      public override void execute_internal (Match? match)
      {
        if (match.match_type == MatchType.APPLICATION)
        {
          ApplicationMatch? app_match = match as ApplicationMatch;
          return_if_fail (app_match != null);

          AppInfo original = app_match.app_info ??
            new DesktopAppInfo.from_filename (app_match.filename);
          AppInfo app = AppInfo.create_from_commandline (
            original.get_commandline (), original.get_name (),
            AppInfoCreateFlags.NEEDS_TERMINAL);

          try
          {
            app.launch (null, new Gdk.AppLaunchContext ());
          }
          catch (Error err)
          {
            warning ("%s", err.message);
          }
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.APPLICATION:
            ApplicationMatch? am = match as ApplicationMatch;
            return am != null;
          default:
            return false;
        }
      }
    }
    
    private class Opener: Action
    {
      public Opener ()
      {
        Object (title: _ ("Open"),
                description: _ ("Open using default application"),
                icon_name: "fileopen", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 80);
      }

      public override void execute_internal (Match? match)
      {
        UriMatch uri_match = match as UriMatch;
        return_if_fail (uri_match != null);
        var f = File.new_for_uri (uri_match.uri);
        try
        {
          var app_info = f.query_default_handler (null);
          List<File> files = new List<File> ();
          files.prepend (f);
          app_info.launch (files, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
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
        Object (title: _ ("Open folder"),
                description: _ ("Open folder containing this file"),
                icon_name: "folder-open", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 70);
      }

      public override void execute_internal (Match? match)
      {
        UriMatch uri_match = match as UriMatch;
        return_if_fail (uri_match != null);
        var f = File.new_for_uri (uri_match.uri);
        f = f.get_parent ();
        try
        {
          var app_info = f.query_default_handler (null);
          List<File> files = new List<File> ();
          files.prepend (f);
          app_info.launch (files, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        if (match.match_type != MatchType.GENERIC_URI) return false;
        UriMatch uri_match = match as UriMatch;
        var f = File.new_for_uri (uri_match.uri);
        var parent = f.get_parent ();
        return parent != null && f.is_native ();
      }
    }
    
    private Gee.List<Action> actions;

    construct
    {
      actions = new Gee.ArrayList<Action> ();
      
      actions.add (new Runner ());
      actions.add (new TerminalRunner ());
      actions.add (new Opener ());
      actions.add (new OpenFolder ());
    }
    
    public override bool handles_unknown ()
    {
      return false;
    }

    public override ResultSet? find_for_match (Query query, Match match)
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
