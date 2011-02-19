/*
 * Copyright (C) 2011 Antono Vasiljev <self@antono.info>
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
 * Authored by Antono Vasiljev <self@antono.info>
 *
 */

namespace Synapse
{
  public class SshPlugin: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate () { }

    public void deactivate () { }

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (SshPlugin),
	"SSH", // Plugin title
        _ ("Connect to host with SSH"), // description
        "terminal",	// icon name
        register_plugin, // reference to this function
        Environment.find_program_in_path ("ssh") != null, // true if user's system has all required components which the plugin needs
        _ ("ssh is not installed") // error message
      );
    }

    private class Connect: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; default = 0; }
      
      public void execute (Match? match)
      {
        try
        {
          AppInfo ai = AppInfo.create_from_commandline (
            "gnome-terminal -e \"ssh %s\"".printf (match.title),
            "ssh", 0);
          ai.launch (null, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public Connect ()
      {
        Object (title: _("Connect with SSH"),
                description: _("Connect with SSH"),
                has_thumbnail: false, icon_name: "terminal");
      }
    }
    

    static construct
    {
      register_plugin ();
    }

    private Connect action;
    private bool has_ssh;
    private Regex host_re;

    construct
    {
      action  = new Connect ();
      has_ssh = Environment.find_program_in_path ("ssh") != null;

      try
      {        
        host_re = new Regex ("^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\\-]*[A-Za-z0-9])$", RegexCompileFlags.OPTIMIZE);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
    }
    
    public bool handles_unknown ()
    {
      return has_ssh;
    }
    

    public ResultSet? find_for_match (Query query, Match match)
    {
      if (!has_ssh || match.match_type != MatchType.UNKNOWN ||
          !(QueryFlags.ACTIONS in query.query_type))
      {
        return null;
      }

      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        int relevancy = action.default_relevancy;
        if (host_re.match (match.title)) relevancy += Match.Score.INCREMENT_SMALL;
        results.add (action, relevancy);
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.CASELESS);
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (action.title))
          {
            results.add (action, matcher.value);
            break;
          }
        }
      }

      return results;
    }
  }
}
