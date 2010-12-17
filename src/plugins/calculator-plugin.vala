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

using Posix;

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

            int pc[2];
            int cp[2];
            if (pipe(pc) < 0) return null;
            if (pipe(cp) < 0) return null;

            int pid = fork();
            if (pid == -1) return null;
            else if (pid == 0) {

                close(1);
                dup(cp[1]);
                close(0);
                dup(pc[0]);
                close(pc[1]);
	            close(cp[0]);
                execlp("bc", "bc", "-l");
                return null;
            }
            
            write(pc[1], query.query_string + "\n", query.query_string.size() + 1);
            close(pc[1]);
            close(cp[1]);
            string s = "";
            char c = 0;
            while(read(cp[0], &c, 1) == 1) {

                if (c == '\n') break; 
                s = s + c.to_string();
            }
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
