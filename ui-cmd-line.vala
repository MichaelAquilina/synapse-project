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

#if CMD_LINE_UI

MainLoop loop;

int main (string[] argv)
{
  if (argv.length <= 1)
  {
    print ("Enter search string as command line argument!\n");
  }
  else
  {
    loop = new MainLoop ();
    var sink = new Sezen.DataSink ();
    string query = argv[1];
    debug (@"Searching for $query");
    sink.search (query, Sezen.QueryFlags.LOCAL_CONTENT, (obj, res) =>
    {
      try
      {
        var rs = sink.search.end (res);
        foreach (var match in rs) debug ("%s", match.title);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      loop.quit ();
    });

    loop.run ();
  }

  return 0;
}
#endif
