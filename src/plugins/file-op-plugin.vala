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
  public class FileOpPlugin : Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
    }

    public void deactivate ()
    {
    }

    private class Remove: Action
    {
      public Remove()
      {
        Object (title: _("Remove"),
                description: _("Move to Trash"),
                icon_name: "user-trash", has_thumbnail: false,
                default_relevancy: MatchScore.POOR);
      }

      public override void do_execute (Match source, Match? target = null)
      {
        unowned UriMatch uri_match = source as UriMatch;
        return_if_fail (uri_match != null);

        var f = File.new_for_uri (uri_match.uri);
        try
        {
           f.trash ();
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        return (match is UriMatch);
      }
    }

    private class RenameTo : Action
    {
      public RenameTo ()
      {
        Object (title: _("Rename to"),
                description: _("Rename the file to..."),
                icon_name: "stock_save-as", has_thumbnail: false,
                default_relevancy: MatchScore.AVERAGE);
      }

      public override void do_execute (Match source, Match? target = null)
      {
        if (target == null) return; // not possible

        unowned UriMatch? uri_match = source as UriMatch;
        if (uri_match == null) return; // not possible

        File f;
        f = File.new_for_uri (uri_match.uri);
        if (!f.query_exists ())
        {
          warning (_("File \"%s\"does not exist."), uri_match.uri);
          return;
        }
        string newpath = Path.build_filename (Path.get_dirname (f.get_path ()), target.title);
        var f2 = File.new_for_path (newpath);
        debug ("Moving \"%s\" to \"%s\"", f.get_path (), newpath);
        bool done = false;
        try {
          done = f.move (f2, GLib.FileCopyFlags.OVERWRITE);
        }catch (GLib.Error err) {}
        if (!done)
        {
          warning (_("Cannot move \"%s\" to \"%s\""), f.get_path (), newpath);
        }
      }

      public override bool needs_target ()
      {
        return true;
      }

      public override QueryFlags target_flags ()
      {
        return QueryFlags.TEXT;
      }

      public override bool valid_for_match (Match match)
      {
        return (match is UriMatch && (((UriMatch) match).file_type & QueryFlags.FILES) != 0);
      }
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (FileOpPlugin),
        _("File Operations"),
        _("Copy, Cut, Paste and Delete files"),
        "stock_copy",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Gee.List<Action> actions;

    construct
    {
      actions = new Gee.ArrayList<Action> ();

      actions.add (new Remove ());
      actions.add (new RenameTo ());
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
