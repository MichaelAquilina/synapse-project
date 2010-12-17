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
 * Authored by Magnus Kulke <mkulke@gmail.com>
 *
 */

namespace Synapse
{
  public class CalculatorPlugin: DataPlugin
  {
    private class Result: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; default = 0; }
      
      public Result (double result)
      {
        Object (match_type: MatchType.UNKNOWN,               
                title: "%g".printf(result),
                description: _ ("Calulate basic expressions"),
                has_thumbnail: true, icon_name: "accessories-calculator");
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (CalculatorPlugin),
        "Calculator",
        _ ("Calulate basic expressions."),
        "accessories-calculator",
        register_plugin,
        Environment.find_program_in_path ("bc") != null,
        _ ("bc is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    construct
    {
    }

    private Regex regex;

    public override async ResultSet? search (Query query) throws SearchError
    { 
        string matchString = query.query_string.replace(" ", "");
        regex = new Regex("^\\(*(-?\\d+(\\.\\d+)?)((\\+|-|\\*|/)\\(*(-?\\d+(\\.\\d+)?)\\)*)+$", RegexCompileFlags.OPTIMIZE);
        if (regex.match(matchString)) {

            Pid pid;
            int read_fd, write_fd;
            string[] argv = {"bc", "-l"};
            Process.spawn_async_with_pipes (null, argv, null,
                                            SpawnFlags.SEARCH_PATH,
                                            null, out pid, out write_fd, out read_fd);
            UnixInputStream read_stream = new UnixInputStream (read_fd, true);
            DataInputStream bc_output = new DataInputStream (read_stream);
            UnixOutputStream write_stream = new UnixOutputStream (write_fd, true);
            DataOutputStream bc_input = new DataOutputStream (write_stream);    
            string? s = null;

            bc_input.write(query.query_string + "\n", query.query_string.size() + 1);
            bc_input.close();

            s = yield bc_output.read_line_async(Priority.DEFAULT_IDLE);

            if (s.size() == 0) return null;
            double d = s.to_double();
            Result result = new Result(d);
            ResultSet results = new ResultSet();
            results.add(result, Match.Score.AVERAGE);
            return results;
        }
        else return null;
    }
  }
}
