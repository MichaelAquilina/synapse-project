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
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

namespace Sezen
{
  [DBus (name = "org.gnome.Rhythmbox.Shell")]
  interface RhythmboxShell : Object {
      [DBus (name = "addToQueue")]
      public abstract void add_to_queue (string uri) throws DBus.Error;
      [DBus (name = "clearQueue")]
      public abstract void clear_queue () throws DBus.Error;
  }
  [DBus (name = "org.gnome.Rhythmbox.Player")]
  interface RhythmboxPlayer : Object {
      [DBus (name = "getPlaying")]
      public abstract bool get_playing () throws DBus.Error;
      [DBus (name = "next")] /* Fix to Vala naming conversion error */
      public abstract void next () throws DBus.Error;
      [DBus (name = "playPause")]
      public abstract void play_pause (bool b) throws DBus.Error;
  }
  public class RhythmboxActions: ActionPlugin
  {
    private abstract class Action: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public string uri { get; set; }
      public MatchType match_type { get; construct set; }
      
      public int default_relevancy { get; set; }
      
      public abstract bool valid_for_match (Match match);
      // stupid Vala...
      public abstract void execute_internal (Match? match);
      public void execute (Match? match)
      {
        execute_internal (match);
      }
    }

    private class AddToPlaylist: Action
    {
      public AddToPlaylist ()
      {
        Object (title: "Enqueue in Rhythmbox", // FIXME: i18n
                description: "Add the song to Rhythmbox playlist",
                icon_name: "media-playback-start", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 101);
      }

      public override void execute_internal (Match? match)
      {
        return_if_fail (match.match_type == MatchType.GENERIC_URI);
        UriMatch uri = match as UriMatch;
        return_if_fail ((uri.file_type & QueryFlags.AUDIO) != 0);
        try {
          var conn = DBus.Bus.get(DBus.BusType.SESSION);
          var shell = (RhythmboxShell) conn.get_object ("org.gnome.Rhythmbox",
                                                      "/org/gnome/Rhythmbox/Shell");
          var player = (RhythmboxPlayer) conn.get_object ("org.gnome.Rhythmbox",
                                                      "/org/gnome/Rhythmbox/Player");
          shell.add_to_queue (uri.uri);
          if (!player.get_playing())
            player.play_pause (true);
        } catch (DBus.Error e) {
          stderr.printf ("Rythmbox is not available.\n%s", e.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            UriMatch uri = match as UriMatch;
            if ((uri.file_type & QueryFlags.AUDIO) != 0)
              return true;
            else
              return false;
          default:
            return false;
        }
      }
    }
    private class PlayNow: Action
    {
      public PlayNow ()
      {
        Object (title: "Play in Rhythmbox", // FIXME: i18n
                description: "Clears the current playlist and plays the song",
                icon_name: "media-playback-start", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: 102);
      }

      public override void execute_internal (Match? match)
      {
        return_if_fail (match.match_type == MatchType.GENERIC_URI);
        UriMatch uri = match as UriMatch;
        return_if_fail ((uri.file_type & QueryFlags.AUDIO) != 0);
        try {
          var conn = DBus.Bus.get(DBus.BusType.SESSION);
          var shell = (RhythmboxShell) conn.get_object ("org.gnome.Rhythmbox",
                                                      "/org/gnome/Rhythmbox/Shell");
          var player = (RhythmboxPlayer) conn.get_object ("org.gnome.Rhythmbox",
                                                      "/org/gnome/Rhythmbox/Player");
          shell.clear_queue ();
          shell.add_to_queue (uri.uri);
          player.next ();
          if (!player.get_playing())
            player.play_pause (true);
        } catch (DBus.Error e) {
          stderr.printf ("Rythmbox is not available.\n%s", e.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        switch (match.match_type)
        {
          case MatchType.GENERIC_URI:
            UriMatch uri = match as UriMatch;
            if ((uri.file_type & QueryFlags.AUDIO) != 0)
              return true;
            else
              return false;
          default:
            return false;
        }
      }
    }
    private Gee.List<Action> actions;

    construct
    {
      actions = new Gee.ArrayList<Action> ();
      
      actions.add (new PlayNow());
      actions.add (new AddToPlaylist());      
    }
    
    public override bool handles_unknown ()
    {
      return false;
    }

    public override ResultSet? find_for_match (Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();
      
      if (query_empty)
      {
        foreach (var action in actions)
        {
          if (action.valid_for_match (match))
          {
            results.add (action, action.default_relevancy);
          }
        }
      }
      else
      {
        var matchers = Query.get_matchers_for_query (query.query_string, 0,
          RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var action in actions)
        {
          if (!action.valid_for_match (match)) continue;
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (action.title))
            {
              results.add (action, matcher.value);
              break;
            }
          }
        }
      }
      
      return results;
    }
  }
}
