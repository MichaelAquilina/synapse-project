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

MainLoop loop;

int main (string[] argv)
{
  loop = new MainLoop ();
  var sink = new Synapse.DataSink ();
  if (argv.length <= 1)
  {
    print ("Searching for recent uris...\n");
    sink.search ("", Synapse.QueryFlags.LOCAL_CONTENT, null, null, (obj, res) =>
    {
      try
      {
        var rs = sink.search.end (res);
        foreach (var match in rs)
        {
          print (">> %s\n", match.title);
          var actions = sink.find_actions_for_match (match, null);
          if (actions.size > 0) print ("  > %s\n", actions[0].title);
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      loop.quit ();
    });
  }
  else
  {
    string query = argv[1];
    debug (@"Searching for \"$query\"...");
    sink.search (query, Synapse.QueryFlags.LOCAL_CONTENT, null, null, (obj, res) =>
    {
      try
      {
        var rs = sink.search.end (res);
        foreach (var match in rs)
        {
          print (">> %s\n", match.title);
          var actions = sink.find_actions_for_match (match, null);
          if (actions.size > 0) print ("  > %s\n", actions[0].title);
        }
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      loop.quit ();
    });
  }

  loop.run ();

  return 0;
}

