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
  public class CommandPlugin: DataPlugin
  {
    private class CommandObject: Object, Match, ApplicationMatch
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public string uri { get; set; }
      public MatchType match_type { get; construct set; }

      // for ApplicationMatch
      public AppInfo? app_info { get; set; default = null; }
      public bool needs_terminal { get; set; default = false; }
      public string? filename { get; construct set; default = null; }
      
      public CommandObject (string cmd)
      {
        Object (title: cmd, description: "Run command", icon_name: "unknown",
                match_type: MatchType.APPLICATION,
                needs_terminal: cmd.has_prefix ("sudo "));

        app_info = AppInfo.create_from_commandline (cmd, null, 0);
      }
    }
    
    static construct
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (CommandPlugin),
        "Commands",
        "Allow execution of arbitrary commands.",
        "system-run"
      );
    }

    private Gee.Set<string> past_commands;
    private Regex split_regex;

    construct
    {
      past_commands = new Gee.HashSet<string> ();
      try
      {
        split_regex = new Regex ("\\s+", RegexCompileFlags.OPTIMIZE);
      }
      catch (RegexError err)
      {
        critical ("%s", err.message);
      }
    }

    public override async ResultSet? search (Query q) throws SearchError
    {
      // we only search for applications
      if (!(QueryFlags.APPLICATIONS in q.query_type)) return null;

      Idle.add (search.callback);
      yield;

      var result = new ResultSet ();

      if (!(q.query_string in past_commands))
      {
        foreach (var command in past_commands)
        {
          if (command.has_prefix (q.query_string))
          {
            // TODO: add result
          }
        }
        
        var stripped = q.query_string.strip ();
        if (stripped == "") return null;
        string[] args = split_regex.split (stripped);
        string? valid_cmd = Environment.find_program_in_path (args[0]);

        if (valid_cmd != null)
        {
          // don't allow dangerous commands
          if (args[0] != "rm")
          {
            // TODO: add result
            result.add (new CommandObject (stripped), Query.MATCH_FUZZY);
          }
        }
      }
      else
      {
        // TODO: add with high relevancy
      }
      
      q.check_cancellable ();

      return result;
    }
  }
}
