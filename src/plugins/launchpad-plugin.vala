/*
 * Copyright (C) 2011 Michal Hruby <michal.mhr@gmail.com>
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
  public class LaunchpadPlugin: Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }

    private class LaunchpadObject: Object, Match, UriMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      // for UriMatch
      public string uri { get; set; }
      public QueryFlags file_type { get; set; }
      public string mime_type { get; set; }
      
      public LaunchpadObject (string title, string desc, string uri)
      {
        Object (title: title, description: desc,
                icon_name: g_content_type_get_icon ("text/html").to_string (),
                match_type: MatchType.GENERIC_URI,
                uri: uri, mime_type: "text/html",
                file_type: QueryFlags.INTERNET);
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (LaunchpadPlugin),
        "Launchpad",
        _ ("Find bugs and branches on Launchpad."),
        "applications-internet",
        register_plugin
      );
    }
    
    static construct
    {
      register_plugin ();
    }

    private Regex bug_regex;
    private Regex branch_regex;

    construct
    {
      try
      {
        bug_regex = new Regex ("(?:bug|lp|#):?\\s*#?\\s*(\\d+)$", RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        branch_regex = new Regex ("lp:(~?[a-z]+[+-/_a-z0-9]*)", RegexCompileFlags.OPTIMIZE);
      }
      catch (RegexError err)
      {
        Utils.Logger.warning (this, "Unable to construct regex: %s", err.message);
      }
    }
    
    public bool handles_query (Query q)
    {
      return (QueryFlags.INTERNET in q.query_type || QueryFlags.ACTIONS in q.query_type);
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      string? uri = null;
      string title = null;
      string description = null;
      var result = new ResultSet ();

      string stripped = q.query_string.strip ();
      if (stripped == "") return null;

      MatchInfo mi;
      if (branch_regex.match (stripped, 0, out mi))
      {
        string branch = mi.fetch (1);
        string[] groups = branch.split ("/");
        if (groups.length == 1)
        {
          // project link (lp:synapse)
          uri = "https://code.launchpad.net/" + branch;
          title = _ ("Launchpad: Bazaar branches for %s").printf (branch);
          description = uri;
        }
        else if (groups.length == 2 && !branch.has_prefix ("~"))
        {
          // series link (lp:synapse/0.3)
          uri = "https://code.launchpad.net/" + branch;
          title = _ ("Launchpad: Series %s for Project %s").printf (groups[1], groups[0]);
          description = uri;
        }
        else if (branch.has_prefix ("~"))
        {
          // branch link (lp:~mhr3/synapse/lp-plugin)
          uri = "https://code.launchpad.net/" + branch;
          title = _ ("Launchpad: Bazaar branch %s").printf (branch);
          description = uri;
        }

        if (uri != null)
        {
          result.add (new LaunchpadObject (title, description, uri),
                      Match.Score.EXCELLENT);
        }
      }
      else if (bug_regex.match (stripped, 0, out mi))
      {
        string bug_num = mi.fetch (1);
        
        uri = "https://bugs.launchpad.net/bugs/" + bug_num;
        title = _ ("Launchpad: Bug #%s").printf (bug_num);
        description = uri;
        result.add (new LaunchpadObject (title, description, uri),
                    Match.Score.ABOVE_AVERAGE);
      }

      q.check_cancellable ();
      return result;
    }
  }
}
