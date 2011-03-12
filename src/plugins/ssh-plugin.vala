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
  public class SshPlugin: Object, Activatable, ItemProvider
  {
    public  bool      enabled { get; set; default = true; }
    private bool      has_ssh;
    private ArrayList<string> hosts;

    static construct
    {
      register_plugin ();
    }

    public void activate ()
    {
      has_ssh = (Environment.find_program_in_path ("ssh") != null);
      parse_ssh_config.begin ();
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

      try
      {
        var dis = new DataInputStream (file.read ());

        // TODO: match key boundary
        Regex host_key_re = new Regex ("(HostName|Host)", RegexCompileFlags.OPTIMIZE);
        Regex comment_re  = new Regex ("#.*$", RegexCompileFlags.OPTIMIZE);

        string line;

        while ((line = yield dis.read_line_async (Priority.DEFAULT)) != null)
        {
          line = comment_re.replace (line, -1, 0, "");
          if (host_key_re.match (line))
          {
            line = host_key_re.replace (line, -1, 0, "");
            foreach (var host in line.split (" "))
            {
              string host_stripped = host.strip ();
              if (host_stripped != "" && host_stripped.str ("*") == null)
              {
                // TODO: no dupes
                // FIXME: handle wildcard hosts somehow
                Utils.Logger.debug (this, "host added: %s\n", host);
                hosts.add (host);
              }
            }
          }
        }
      }
      catch (Error e)
      {
        Utils.Logger.warning (this, "%s: %s", file.get_path (), e.message);
      }
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.ACTIONS in query.query_type ||
        QueryFlags.INTERNET in query.query_type);
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      Idle.add (search.callback);
      yield;
      query.check_cancellable ();

      var results = new ResultSet ();

      foreach (var host in hosts)
      {
        int score = 0;
        if (host == query.query_string)
        {
          score = Match.Score.GOOD;
        }
        else if (host.has_prefix (query.query_string))
        {
          score = Match.Score.BELOW_AVERAGE;
        }
        else
        {
          continue;
        }
        results.add (new SshHost (host), score);
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
  }
}

// vim: expandtab softtabsstop tabstop=2

