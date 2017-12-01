/*
 * Copyright (C) 2017 André Nasturas <andre.nasturas+synapse@delfosia.net>
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
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA. *
 */

namespace Synapse
{
  public class RolldicePlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {

    }

    public void deactivate ()
    {

    }

    private class Result : TextMatch
    {
      public int default_relevancy { get; set; default = 0; }

      public Result (string result, string match_string)
      {
        Object (
          title: "%s".printf (result),
          description: "%s : %s".printf (match_string, result),
          has_thumbnail: false,
          icon_name: "applications-boardgames"
        );
      }

      public override string get_text ()
      {
        return title;
      }
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (RolldicePlugin),
        _("Rolldice"),
        _("Rolls virtual dice."),
        "applications-boardgames",
        register_plugin,
        Environment.find_program_in_path ("rolldice") != null,
        _("rolldice is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Regex regex;

    construct
    {
      /*
          This regex is based on the regex provided by rolldice documentation.
          It should catch a string formed like 6x5d7*2+4s3, which will be interpreted as
          "Roll five seven-sized dices, drop the lowest three, multiply the result by 2 and add 4,
          and do it 6 times independently."
          Also added a specific modification to prevent the regex catching "d0" and "d1" substrings
          (zero-sized and one-sized dice) to prevent unexcepted results (as it is not supported by
          rolldice, it may throw 6-sized dices instead, which could be surprising when the user ask
          for one one-sized dice and could except a 1 as result.)  
      */

      try
      {
        regex = new Regex (
          "^([0-9]+x)?[0-9]*d(([2-9]|[1-9][0-9]+)|%)(\\*[0-9]+)?((\\+|\\-)[0-9]+)?(s[0-9]+)?$",
          RegexCompileFlags.OPTIMIZE);
      } catch (Error e) {
        critical ("Error creating regexp.");
      }
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.ACTIONS in query.query_type);
    }

    public async ResultSet? search (Query query) throws SearchError
    {
      string input = query.query_string.replace (" ", "");
      bool matched = regex.match (input);
      if (!matched && input.length > 1)
      {
        input = input[0 : input.length - 1];
        matched = regex.match (input);
      }
      if (matched)
      {
        Pid pid;
        int read_fd, write_fd;
        string[] argv = {"rolldice"};
        string? solution = null;

        try
        {
          Process.spawn_async_with_pipes (null, argv, null,
                                          SpawnFlags.SEARCH_PATH,
                                          null, out pid, out write_fd, out read_fd);
          UnixInputStream read_stream = new UnixInputStream (read_fd, true);
          DataInputStream rolldice_output = new DataInputStream (read_stream);

          UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);
          DataOutputStream rolldice_input = new DataOutputStream (write_stream);

          rolldice_input.put_string (input + "\n", query.cancellable);
          yield rolldice_input.close_async (Priority.DEFAULT, query.cancellable);
          solution = yield rolldice_output.read_line_async (Priority.DEFAULT_IDLE, query.cancellable);
          solution = yield rolldice_output.read_line_async (Priority.DEFAULT_IDLE, query.cancellable);
          /* As rolldice send the input on the standard output, we read it twice to get the result */

          if (solution != null)
          {
            ResultSet results = new ResultSet ();
            string[] solutions = solution.split(" ");

            for (int i = 0; i < solutions.length; i++)
            {
              string s = solutions[i];
              if (s.length > 0)   // Prevent empty solutions due to the split with a final whitespace
              {
                Result result = new Result (s, query.query_string);
                results.add (result, MatchScore.AVERAGE+i);  // Prevent ResultSet to be sorted
              }
            }
            query.check_cancellable ();
            return results;
          }
        }
        catch (Error err)
        {
          if (!query.is_cancelled ()) warning ("%s", err.message);
        }
      }

      query.check_cancellable ();
      return null;
    }
  }
}
