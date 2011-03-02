/*
 * Copyright (C) 2011 Antono Vasiljev <self@antono.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
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

using Gee;

namespace Synapse
{
  public class SshPlugin: Object, Activatable, ActionProvider, ItemProvider
  {
    public  bool      enabled { get; set; default = true; }
    private Connect   action;
    private bool      has_ssh;
    private ArrayList<string> hosts;

    static construct
    {
      register_plugin ();
    }

    public void activate ()
    {
      action  = new Connect ();
      has_ssh = (Environment.find_program_in_path ("ssh") != null);
      parse_ssh_config.begin();
    }

    public void deactivate () {}

    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (SshPlugin),
    		"SSH", // Plugin title
        _ ("Connect to host with SSH"), // description
        "terminal",	// icon name
        register_plugin, // reference to this function
    		// true if user's system has all required components which the plugin needs
        (Environment.find_program_in_path ("ssh") != null),
        _ ("ssh is not installed") // error message
      );
    }

    private async void parse_ssh_config ()
    {
      var file = File.new_for_path (Environment.get_home_dir () + "/.ssh/config");

      hosts = new ArrayList<string> ();

      if (!file.query_exists ())
      {
        stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
      }

      try
      {
        var dis = new DataInputStream (file.read ());

        // TODO: match key boundary
        Regex host_key_re = new Regex("(HostName|Host)", RegexCompileFlags.OPTIMIZE);
        Regex comment_re  = new Regex("#.*$", RegexCompileFlags.OPTIMIZE);

        string line;

        while ((line = dis.read_line (null)) != null)
        {
          line = comment_re.replace(line, -1, 0, "");
          if (host_key_re.match(line))
          {
            line = host_key_re.replace(line, -1, 0, "");
            foreach (var host in line.split(" "))
            {
              if (host != "")
              {
                // TODO: get rid of longer empty strings
                // TODO: no dupes
                Utils.Logger.debug(this, "host added: %s\n", host);
                hosts.add(host);
              }
            }
          }
        }
      }
      catch (Error e)
      {
        error ("%s", e.message);
      }
    }

    // Connect Action
    private class Connect : Object, Match
    {
      // from Match interface
      public string title             { get; construct set; }
      public string description       { get; set; }
      public string icon_name         { get; construct set; }
      public bool   has_thumbnail     { get; construct set; }
      public string thumbnail_path    { get; construct set; }
      public int    default_relevancy { get; set; default = 0; }
      public MatchType match_type 	  { get; construct set; }

      public void execute (Match? match)
      {
        try
        {
          AppInfo.create_from_commandline ("ssh %s".printf (match.title),
            "ssh", AppInfoCreateFlags.NEEDS_TERMINAL)
              .launch (null, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      public Connect ()
      {
      	Object (title: _("Connect with SSH"),
                description: _("Connect to remote host with SSH"),
                has_thumbnail: false, icon_name: "terminal");
      }
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.ACTIONS in query.query_type ||
        QueryFlags.INTERNET in query.query_type);
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      var results = new ResultSet ();

      foreach (var host in hosts)
      {
        if (host.has_prefix(query.query_string))
        {
          // TODO: add better score if exact match
          results.add (new SshHost (host), Match.Score.AVERAGE);
        }
      }

      query.check_cancellable ();

      return results;
    }

    private class SshHost : Object, Match
    {
      public string title           { get; construct set; }
      public string description     { get; set; }
      public string icon_name       { get; construct set; }
      public bool   has_thumbnail   { get; construct set; }
      public string thumbnail_path  { get; construct set; }
      public MatchType match_type   { get; construct set; }

      public void execute (Match? match)
      {
        try
        {
          AppInfo ai = AppInfo.create_from_commandline (
            "ssh %s".printf (this.title),
            "ssh", AppInfoCreateFlags.NEEDS_TERMINAL);
          ai.launch (null, new Gdk.AppLaunchContext ());
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      public SshHost (string host_name)
      {
        Object (
          match_type: MatchType.ACTION,
          title: host_name,
          description: _("Connect with SSH"),
          has_thumbnail: false,
          icon_name: "terminal"
        );
      }
    }

    public ResultSet? find_for_match (Query query, Match match)
    {
      if (!has_ssh) return null;

      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        results.add (action, action.default_relevancy);
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0, RegexCompileFlags.CASELESS);
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

// vim: expandtab softtabsstop tabstop=2

