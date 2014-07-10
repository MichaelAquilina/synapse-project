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

namespace Synapse
{
  [DBus (name = "org.bansheeproject.Banshee.PlayerEngine")]
  interface BansheePlayerEngine : Object {
      public const string UNIQUE_NAME = "org.bansheeproject.Banshee";
      public const string OBJECT_PATH = "/org/bansheeproject/Banshee/PlayerEngine";

      public abstract void play () throws IOError;
      public abstract void pause () throws IOError;
      public abstract void open (string uri) throws IOError;
  }

  [DBus (name = "org.bansheeproject.Banshee.PlaybackController")]
  interface BansheePlaybackController : Object {
      public const string UNIQUE_NAME = "org.bansheeproject.Banshee";
      public const string OBJECT_PATH = "/org/bansheeproject/Banshee/PlaybackController";

      public abstract void next (bool restart) throws IOError;
      public abstract void previous (bool restart) throws IOError;
  }

  [DBus (name = "org.bansheeproject.Banshee.PlayQueue")]
  interface BansheePlayQueue : Object {
      public const string UNIQUE_NAME = "org.bansheeproject.Banshee";
      public const string OBJECT_PATH = "/org/bansheeproject/Banshee/SourceManager/PlayQueue";

      public abstract void enqueue_uri (string uri, bool prepend) throws IOError;
  }

  public class BansheeActions : Object, Activatable, ItemProvider, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {

    }

    public void deactivate ()
    {

    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (BansheeActions),
        "Banshee",
        _("Control Banshee and add items to playlists."),
        "banshee",
        register_plugin,
        Environment.find_program_in_path ("banshee") != null ||
        Environment.find_program_in_path ("banshee-1") != null,
        //DBusService.get_default ().name_is_activatable (BansheePlaybackController.UNIQUE_NAME), // doesn't work for banshee
        _("Banshee is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private abstract class BansheeAction : Action
    {
      public virtual int get_relevancy ()
      {
        bool banshee_running = DBusService.get_default ().name_has_owner (BansheePlayerEngine.UNIQUE_NAME);
        return banshee_running ? default_relevancy + MatchScore.INCREMENT_LARGE : default_relevancy;
      }

      public virtual bool action_available ()
      {
        return DBusService.get_default ().name_has_owner (BansheePlayerEngine.UNIQUE_NAME);
      }
    }

    private abstract class BansheeControlMatch : ActionMatch
    {
      public virtual bool action_available ()
      {
        return DBusService.get_default ().name_has_owner (
          BansheePlayerEngine.UNIQUE_NAME);
      }
    }

    /* MATCHES of Type.ACTION */
    private class Play : BansheeControlMatch
    {
      public Play ()
      {
        Object (title: _("Play"),
                description: _("Start playback in Banshee"),
                icon_name: "media-playback-start", has_thumbnail: false);
      }

      public override void do_action ()
      {
        try {
          BansheePlayerEngine player = Bus.get_proxy_sync (BusType.SESSION,
                                           BansheePlayerEngine.UNIQUE_NAME,
                                           BansheePlayerEngine.OBJECT_PATH);

          player.play ();
        } catch (IOError e) {
          stderr.printf ("Banshee is not available.\n%s", e.message);
        }
      }

      public override bool action_available ()
      {
        return true;
      }
    }
    private class Pause : BansheeControlMatch
    {
      public Pause ()
      {
        Object (title: _("Pause"),
                description: _("Pause playback in Banshee"),
                icon_name: "media-playback-pause", has_thumbnail: false);
      }
      public override void do_action ()
      {
        try {
          BansheePlayerEngine player = Bus.get_proxy_sync (BusType.SESSION,
                                           BansheePlayerEngine.UNIQUE_NAME,
                                           BansheePlayerEngine.OBJECT_PATH);
          player.pause ();
        } catch (IOError e) {
          stderr.printf ("Banshee is not available.\n%s", e.message);
        }
      }
    }
    private class Next : BansheeControlMatch
    {
      public Next ()
      {
        Object (title: _("Next"),
                description: _("Plays the next song in Banshee's playlist"),
                icon_name: "media-skip-forward", has_thumbnail: false);
      }

      public override void do_action ()
      {
        try {
          BansheePlaybackController player = Bus.get_proxy_sync (BusType.SESSION,
                                           BansheePlaybackController.UNIQUE_NAME,
                                           BansheePlaybackController.OBJECT_PATH);

          player.next (false);
        } catch (IOError e) {
          stderr.printf ("Banshee is not available.\n%s", e.message);
        }
      }
    }
    private class Previous : BansheeControlMatch
    {
      public Previous ()
      {
        Object (title: _("Previous"),
                description: _("Plays the previous song in Banshee's playlist"),
                icon_name: "media-skip-backward", has_thumbnail: false);
      }

      public override void do_action ()
      {
        try {
          BansheePlaybackController player = Bus.get_proxy_sync (BusType.SESSION,
                                           BansheePlaybackController.UNIQUE_NAME,
                                           BansheePlaybackController.OBJECT_PATH);
          player.previous (false);
        } catch (IOError e) {
          stderr.printf ("Banshee is not available.\n%s", e.message);
        }
      }
    }
    /* ACTIONS FOR MP3s */
    private class AddToPlaylist : BansheeAction
    {
      public AddToPlaylist ()
      {
        Object (title: _("Enqueue in Banshee"),
                description: _("Add the song to Banshee playlist"),
                icon_name: "media-playback-start", has_thumbnail: false,
                default_relevancy: MatchScore.AVERAGE);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        unowned UriMatch? uri = match as UriMatch;
        return_if_fail (uri != null);
        return_if_fail ((uri.file_type & QueryFlags.AUDIO) != 0 ||
                        (uri.file_type & QueryFlags.VIDEO) != 0);
        try {
          BansheePlayQueue player = Bus.get_proxy_sync (BusType.SESSION,
                                           BansheePlayQueue.UNIQUE_NAME,
                                           BansheePlayQueue.OBJECT_PATH);

          player.enqueue_uri (uri.uri, false);
        } catch (IOError e) {
          stderr.printf ("Banshee is not available.\n%s", e.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        unowned UriMatch? uri_match = match as UriMatch;
        if (uri_match == null)
          return false;

        return ((uri_match.file_type & QueryFlags.AUDIO) != 0 ||
                (uri_match.file_type & QueryFlags.VIDEO) != 0);
      }
    }
    private class PlayNow : BansheeAction
    {
      public PlayNow ()
      {
        Object (title: _("Play in Banshee"),
                description: _("Clears the current playlist and plays the song"),
                icon_name: "media-playback-start", has_thumbnail: false,
                default_relevancy: MatchScore.ABOVE_AVERAGE);
      }

      public override void do_execute (Match match, Match? target = null)
      {
        unowned UriMatch? uri = match as UriMatch;
        return_if_fail (uri != null);
        return_if_fail ((uri.file_type & QueryFlags.AUDIO) != 0 ||
                        (uri.file_type & QueryFlags.VIDEO) != 0);
        try {
          BansheePlayerEngine player = Bus.get_proxy_sync (BusType.SESSION,
                                           BansheePlayerEngine.UNIQUE_NAME,
                                           BansheePlayerEngine.OBJECT_PATH);
          player.open (uri.uri);
          player.play ();
        } catch (IOError e) {
          stderr.printf ("Banshee is not available.\n%s", e.message);
        }
      }

      public override bool valid_for_match (Match match)
      {
        unowned UriMatch? uri_match = match as UriMatch;
        if (uri_match == null)
          return false;

        return ((uri_match.file_type & QueryFlags.AUDIO) != 0 ||
                (uri_match.file_type & QueryFlags.VIDEO) != 0);
      }
    }
    private Gee.List<BansheeAction> actions;
    private Gee.List<BansheeControlMatch> matches;

    construct
    {
      actions = new Gee.ArrayList<BansheeAction> ();
      matches = new Gee.ArrayList<BansheeControlMatch> ();

      actions.add (new PlayNow());
      actions.add (new AddToPlaylist());

      matches.add (new Play ());
      matches.add (new Pause ());
      matches.add (new Previous ());
      matches.add (new Next ());
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      // we only search for actions
      if (!(QueryFlags.ACTIONS in q.query_type)) return null;

      var result = new ResultSet ();

      var matchers = Query.get_matchers_for_query (q.query_string, 0,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var action in matches)
      {
        if (!action.action_available ()) continue;
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (action.title))
          {
            result.add (action, matcher.value - MatchScore.INCREMENT_SMALL);
            break;
          }
        }
      }

      q.check_cancellable ();

      return result;
    }

    public ResultSet? find_for_match (ref Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();

      if (query_empty)
      {
        foreach (var action in actions)
        {
          if (action.valid_for_match (match))
          {
            results.add (action, action.get_relevancy ());
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
