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
  public abstract class Action : Match
  {
    public int default_relevancy { get; set; }
    public bool notify_match { get; set; default = true; }

    public abstract bool valid_for_match (Match match);

    public virtual int get_relevancy_for_match (Match match)
    {
      return default_relevancy;
    }

    public abstract void do_execute (Match source, Match? target = null);

    public override void execute_with_target (Match source, Match? target = null)
    {
      do_execute (source, target);
      if (notify_match) source.executed ();
    }
  }

  public class CommonActions : Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
    }

    public void deactivate ()
    {
    }

    private class Runner : Action
    {
      public Runner ()
      {
        Object (title: _("Run"),
                description: _("Run an application, action or script"),
                icon_name: "system-run", has_thumbnail: false,
                default_relevancy: MatchScore.EXCELLENT);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        if (match is ApplicationMatch)
        {
          unowned ApplicationMatch app_match = (ApplicationMatch) match;

          AppInfo app = app_match.app_info ??
            new DesktopAppInfo.from_filename (app_match.filename);

          try
          {
            var display = Gdk.Display.get_default ();
            app.launch (null, display.get_app_launch_context ());

            RelevancyService.get_default ().application_launched (app);
          }
          catch (Error err)
          {
            warning ("%s", err.message);
          }
        }
        else if (match is ActionMatch)
        {
          ((ActionMatch) match).do_action ();
        }
        else if (match is Action)
        {
          ((Action) match).do_execute (match, target);
        }
        else
        {
          warning ("'%s' is not be handled here", match.title);
        }
      }

      public override bool valid_for_match (Match match)
      {
        return (match is Action ||
                match is ActionMatch ||
               (match is ApplicationMatch && !(((ApplicationMatch) match).needs_terminal)));
      }
    }

    private class TerminalRunner : Action
    {
      public TerminalRunner ()
      {
        Object (title: _("Run in Terminal"),
                description: _("Run application or command in terminal"),
                icon_name: "terminal", has_thumbnail: false,
                default_relevancy: MatchScore.BELOW_AVERAGE);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        if (match is ApplicationMatch)
        {
          unowned ApplicationMatch app_match = (ApplicationMatch) match;

          AppInfo original = app_match.app_info ??
            new DesktopAppInfo.from_filename (app_match.filename);

          try
          {
            AppInfo app = AppInfo.create_from_commandline (
              original.get_commandline (), original.get_name (),
              AppInfoCreateFlags.NEEDS_TERMINAL);
            var display = Gdk.Display.get_default ();
            app.launch (null, display.get_app_launch_context ());
          }
          catch (Error err)
          {
            warning ("%s", err.message);
          }
        }
      }

      public override bool valid_for_match (Match match)
      {
        return (match is ApplicationMatch);
      }
    }

    private class Opener : Action
    {
      public Opener ()
      {
        Object (title: _("Open"),
                description: _("Open using default application"),
                icon_name: "fileopen", has_thumbnail: false,
                default_relevancy: MatchScore.GOOD);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        unowned UriMatch? uri_match = match as UriMatch;

        if (uri_match != null)
        {
          Utils.open_uri (uri_match.uri);
        }
        else if (file_path.match (match.title))
        {
          File f;
          if (match.title.has_prefix ("~"))
          {
            f = File.new_for_path (Path.build_filename (Environment.get_home_dir (),
                                                        match.title.substring (1),
                                                        null));
          }
          else
          {
            f = File.new_for_path (match.title);
          }
          Utils.open_uri (f.get_uri ());
        }
        else
        {
          Utils.open_uri (match.title);
        }
      }

      public override bool valid_for_match (Match match)
      {
        return (match is UriMatch || 
               (match is UnknownMatch && (web_uri.match (match.title) || file_path.match (match.title))));
      }

      private Regex web_uri;
      private Regex file_path;

      construct
      {
        try
        {
          web_uri = new Regex ("^(ftp|http(s)?)://[^.]+\\.[^.]+", RegexCompileFlags.OPTIMIZE);
          file_path = new Regex ("^(/|~/)[^/]+", RegexCompileFlags.OPTIMIZE);
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
    }

    private class OpenFolder : Action
    {
      public OpenFolder ()
      {
        Object (title: _("Open folder"),
                description: _("Open folder containing this file"),
                icon_name: "folder-open", has_thumbnail: false,
                default_relevancy: MatchScore.AVERAGE);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        unowned UriMatch? uri_match = match as UriMatch;
        return_if_fail (uri_match != null);

        var f = File.new_for_uri (uri_match.uri);
        f = f.get_parent ();
        try
        {
          var app_info = f.query_default_handler (null);
          List<File> files = new List<File> ();
          files.prepend (f);
          var display = Gdk.Display.get_default ();
          app_info.launch (files, display.get_app_launch_context ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        unowned UriMatch? uri_match = match as UriMatch;
        if (uri_match == null) return false;

        var f = File.new_for_uri (uri_match.uri);
        var parent = f.get_parent ();
        return parent != null && f.is_native ();
      }
    }

    private class ClipboardCopy : Action
    {
      public ClipboardCopy ()
      {
        Object (title: _("Copy to Clipboard"),
                description: _("Copy selection to clipboard"),
                icon_name: "gtk-copy", has_thumbnail: false,
                default_relevancy: MatchScore.AVERAGE);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        var cb = Gtk.Clipboard.get (Gdk.Atom.NONE);
        if (match is UriMatch)
        {
          unowned UriMatch uri_match = (UriMatch) match;

          /*
           // just wow, Gtk and also Vala are trying really hard to make this hard to do...
          Gtk.TargetEntry[] no_entries = {};
          Gtk.TargetList l = new Gtk.TargetList (no_entries);
          l.add_uri_targets (0);
          l.add_text_targets (0);
          Gtk.TargetEntry te = Gtk.target_table_new_from_list (l, 2);
          cb.set_with_data ();
          */
          cb.set_text (uri_match.uri, -1);
        }
        else if (match is TextMatch)
        {
          unowned TextMatch text_match = (TextMatch) match;

          string content = text_match != null ? text_match.get_text () : match.title;

          cb.set_text (content, -1);
        }
      }

      public override bool valid_for_match (Match match)
      {
        return (match is UriMatch || match is TextMatch);
      }

      public override int get_relevancy_for_match (Match match)
      {
        unowned TextMatch? text_match = match as TextMatch;
        if (text_match != null && text_match.text_origin == TextOrigin.CLIPBOARD)
        {
          return 0;
        }

        return default_relevancy;
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
      actions.add (new ClipboardCopy ());
    }

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        foreach (var action in actions)
        {
          if (action.valid_for_match (match))
          {
            results.add (action, action.get_relevancy_for_match (match));
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
