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

namespace Synapse
{
  public class DesktopFilePlugin : Object, Activatable, ItemProvider, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {

    }

    public void deactivate ()
    {

    }

    private class DesktopFileMatch : ApplicationMatch
    {
      public DesktopFileInfo desktop_info { get; construct; }
      public string title_folded { get; construct; }
      public string title_unaccented { get; construct; }
      public string desktop_id { get; construct; }
      public string exec { get; construct; }

      public DesktopFileMatch (DesktopFileInfo info)
      {
        Object (desktop_info : info);
      }

      construct
      {
        filename = desktop_info.filename;
        title = desktop_info.name;
        description = desktop_info.comment;
        icon_name = desktop_info.icon_name;
        exec = desktop_info.exec;
        needs_terminal = desktop_info.needs_terminal;
        title_folded = desktop_info.get_name_folded () ?? title.casefold ();
        title_unaccented = Utils.remove_accents (title_folded);
        desktop_id = "application://" + desktop_info.desktop_id;
      }
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (DesktopFilePlugin),
        "Application Search",
        _("Search for and run applications on your computer."),
        "system-run",
        register_plugin
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Gee.List<DesktopFileMatch> desktop_files;

    construct
    {
      desktop_files = new Gee.ArrayList<DesktopFileMatch> ();
      mimetype_map = new Gee.HashMap<string, OpenWithAction> ();

      var dfs = DesktopFileService.get_default ();
      dfs.reload_started.connect (() => {
        loading_in_progress = true;
      });
      dfs.reload_done.connect (() => {
        mimetype_map.clear ();
        desktop_files.clear ();
        load_all_desktop_files.begin ();
      });

      load_all_desktop_files.begin ();
    }

    public signal void load_complete ();
    private bool loading_in_progress = false;

    private async void load_all_desktop_files ()
    {
      loading_in_progress = true;
      Idle.add_full (Priority.LOW, load_all_desktop_files.callback);
      yield;

      var dfs = DesktopFileService.get_default ();

      foreach (DesktopFileInfo dfi in dfs.get_desktop_files ())
      {
        desktop_files.add (new DesktopFileMatch (dfi));
      }

      loading_in_progress = false;
      load_complete ();
    }

    private int compute_relevancy (DesktopFileMatch dfm, int base_relevancy)
    {
      var rs = RelevancyService.get_default ();
      float popularity = rs.get_application_popularity (dfm.desktop_id);

      int r = RelevancyService.compute_relevancy (base_relevancy, popularity);
      debug ("relevancy for %s: %d", dfm.desktop_id, r);

      return r;
    }

    private void full_search (Query q, ResultSet results,
                              MatcherFlags flags = 0)
    {
      // try to match against global matchers and if those fail, try also exec
      var matchers = Query.get_matchers_for_query (q.query_string_folded,
                                                   flags);

      foreach (var dfm in desktop_files)
      {
        unowned string folded_title = dfm.title_folded;
        unowned string unaccented_title = dfm.title_unaccented;
        bool matched = false;
        // FIXME: we need to do much smarter relevancy computation in fuzzy re
        // "sysmon" matching "System Monitor" is very good as opposed to
        // "seto" matching "System Monitor"
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (folded_title))
          {
            results.add (dfm, compute_relevancy (dfm, matcher.value));
            matched = true;
            break;
          }
          else if (unaccented_title != null && matcher.key.match (unaccented_title))
          {
            results.add (dfm, compute_relevancy (dfm, matcher.value - MatchScore.INCREMENT_SMALL));
            matched = true;
            break;
          }
        }
        if (!matched && dfm.exec.has_prefix (q.query_string))
        {
          results.add (dfm, compute_relevancy (dfm, dfm.exec == q.query_string ?
            MatchScore.VERY_GOOD : MatchScore.AVERAGE - MatchScore.INCREMENT_SMALL));
        }
      }
    }

    public bool handles_query (Query q)
    {
      // we only search for applications
      if (!(QueryFlags.APPLICATIONS in q.query_type)) return false;
      if (q.query_string.strip () == "") return false;

      return true;
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      if (loading_in_progress)
      {
        // wait
        ulong signal_id = this.load_complete.connect (() => {
          search.callback ();
        });
        yield;
        SignalHandler.disconnect (this, signal_id);
      }
      else
      {
        // we'll do this so other plugins can send their DBus requests etc.
        // and they don't have to wait for our blocking (though fast) search
        // to finish
        Idle.add_full (Priority.HIGH_IDLE, search.callback);
        yield;
      }

      q.check_cancellable ();

      // FIXME: spawn new thread and do the search there?
      var result = new ResultSet ();

      if (q.query_string.char_count () == 1)
      {
        var flags = MatcherFlags.NO_SUBSTRING | MatcherFlags.NO_PARTIAL |
                    MatcherFlags.NO_FUZZY;
        full_search (q, result, flags);
      }
      else
      {
        full_search (q, result);
      }

      q.check_cancellable ();

      return result;
    }

    private class OpenWithAction : Action
    {
      public DesktopFileInfo desktop_info { get; construct; }

      public OpenWithAction (DesktopFileInfo info)
      {
        Object (desktop_info : info);
      }

      construct
      {
        title = _("Open with %s").printf (desktop_info.name);
        icon_name = desktop_info.icon_name;
        description = _("Opens current selection using %s").printf (desktop_info.name);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        unowned UriMatch? uri_match = match as UriMatch;
        return_if_fail (uri_match != null);

        var f = File.new_for_uri (uri_match.uri);
        try
        {
          var app_info = new DesktopAppInfo.from_filename (desktop_info.filename);
          List<File> files = new List<File> ();
          files.prepend (f);
          app_info.launch (files, null);
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

    private Gee.Map<string, Gee.List<OpenWithAction>> mimetype_map;

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      unowned UriMatch? uri_match = match as UriMatch;
      if (uri_match == null || uri_match.mime_type == null) return null;

      Gee.List<OpenWithAction> ow_list = mimetype_map[uri_match.mime_type];
      /* Query DesktopFileService only if is necessary */
      if (ow_list == null)
      {
        /* Initialize ow_list */
        ow_list = new Gee.LinkedList<OpenWithAction> ();
        mimetype_map[uri_match.mime_type] = ow_list;
        var dfs = DesktopFileService.get_default ();
        var list_for_mimetype = dfs.get_desktop_files_for_type (uri_match.mime_type);
        /* If there's more than one application, fill the ow list */
        if (list_for_mimetype.size > 1)
        {
          foreach (var entry in list_for_mimetype)
          {
            ow_list.add (new OpenWithAction (entry));
          }
        }
        else return null;
      }
      else if (ow_list.size == 0) return null;

      var rs = new ResultSet ();

      if (query.query_string == "")
      {
        foreach (var action in ow_list)
        {
          rs.add (action, MatchScore.POOR);
        }
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var action in ow_list)
        {
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (action.title))
            {
              rs.add (action, matcher.value);
              break;
            }
          }
        }
      }

      return rs;
    }
  }
}
