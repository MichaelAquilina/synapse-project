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
  public class DesktopFilePlugin: ActionPlugin
  {
    private class DesktopFileMatch: Object, Match, ApplicationMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      // for ApplicationMatch
      public AppInfo? app_info { get; set; default = null; }
      public bool needs_terminal { get; set; default = false; }
      public string? filename { get; construct set; }

      private string? title_folded = null;
      public unowned string get_title_folded ()
      {
        if (title_folded == null) title_folded = title.casefold ();
        return title_folded;
      }

      public string exec { get; set; }

      public DesktopFileMatch.for_info (DesktopFileInfo info)
      {
        Object (filename: info.filename, match_type: MatchType.APPLICATION);

        init_from_info (info);
      }

      private void init_from_info (DesktopFileInfo info)
      {
        this.title = info.name;
        this.description = info.comment;
        this.icon_name = info.icon_name;
        this.exec = info.exec;
        this.needs_terminal = info.needs_terminal;
        this.title_folded = info.get_name_folded ();
      }
    }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (DesktopFilePlugin),
        "Applications",
        _ ("Search applications on your computer."),
        "system-run",
        register_plugin
      );
    }
    
    static construct
    {
      register_plugin ();
    }
    
    protected override bool handles_unknown ()
    {
      return false;
    }
    
    protected override bool provides_data ()
    {
      return true;
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
        load_all_desktop_files ();
      });

      load_all_desktop_files ();
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
        desktop_files.add (new DesktopFileMatch.for_info (dfi));
      }

      loading_in_progress = false;
      load_complete ();
    }

    private void simple_search (Query q, ResultSet results)
    {
      // search method used for 1 letter searches
      unowned string query = q.query_string_folded;

      foreach (var dfi in desktop_files)
      {
        if (dfi.get_title_folded ().has_prefix (query))
        {
          results.add (dfi, Query.MATCH_PREFIX);
        }
        else if (dfi.exec.has_prefix (q.query_string))
        {
          results.add (dfi, 60);
        }
      }
    }

    private void full_search (Query q, ResultSet results)
    {
      // try to match against global matchers and if those fail, try also exec
      var matchers = Query.get_matchers_for_query (q.query_string_folded);

      foreach (var dfi in desktop_files)
      {
        unowned string folded_title = dfi.get_title_folded ();
        bool matched = false;
        // FIXME: we need to do much smarter relevancy computation in fuzzy re
        // "sysmon" matching "System Monitor" is very good as opposed to
        // "seto" matching "System Monitor"
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (folded_title))
          {
            results.add (dfi, matcher.value);
            matched = true;
            break;
          }
        }
        if (!matched && dfi.exec.has_prefix (q.query_string))
        {
          results.add (dfi, dfi.exec == q.query_string ? 85 : 65);
        }
      }
    }

    public override async ResultSet? search (Query q) throws SearchError
    {
      // we only search for applications
      if (!(QueryFlags.APPLICATIONS in q.query_type)) return null;

      if (loading_in_progress)
      {
        // wait
        ulong signal_id = this.load_complete.connect (() =>
        {
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

      if (q.query_string.length == 1)
      {
        simple_search (q, result);
      }
      else
      {
        full_search (q, result);
      }

      q.check_cancellable ();

      return result;
    }
    
    private class OpenWithAction: Object, Match
    {
       // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public DesktopFileInfo desktop_info { get; private set; }
      
      public OpenWithAction (DesktopFileInfo info)
      {
        Object ();
        
        init_with_info (info);
      }

      private void init_with_info (DesktopFileInfo info)
      {
        this.title = _ ("Open with %s").printf (info.name);
        this.icon_name = info.icon_name;
        this.description = _ ("Opens current selection using %s").printf (info.name);
        this.desktop_info = info;
      }
      
      protected void execute (Match? match)
      {
        UriMatch uri_match = match as UriMatch;
        return_if_fail (uri_match != null);
        
        var f = File.new_for_uri (uri_match.uri);
        try
        {
          var app_info = new DesktopAppInfo.from_filename (desktop_info.filename);
          List<File> files = new List<File> ();
          files.prepend (f);
          app_info.launch (files, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
    }
    
    private Gee.Map<string, Gee.List<OpenWithAction> > mimetype_map;

    public override ResultSet? find_for_match (Query query, Match match)
    {
      if (match.match_type != MatchType.GENERIC_URI) return null;

      var uri_match = match as UriMatch;
      return_val_if_fail (uri_match != null, null);
      
      if (uri_match.mime_type == null) return null;
      var dfs = DesktopFileService.get_default ();

      var list_for_mimetype = dfs.get_desktop_files_for_type (uri_match.mime_type);
      if (list_for_mimetype.size < 2) return null;

      var rs = new ResultSet ();
      Gee.List<OpenWithAction> ow_list = mimetype_map[uri_match.mime_type];
      if (ow_list == null)
      {
        ow_list = new Gee.LinkedList<OpenWithAction> ();
        mimetype_map[uri_match.mime_type] = ow_list;
        foreach (var entry in list_for_mimetype)
        {
          ow_list.add (new OpenWithAction (entry));
        }
      }
      
      if (query.query_string == "")
      {
        foreach (var action in ow_list)
        {
          rs.add (action, Query.MATCH_FUZZY);
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
