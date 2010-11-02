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

namespace Sezen
{
  public class ZeitgeistPlugin: DataPlugin
  {
    private class MatchObject: Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public string uri { get; set; }
      public MatchType match_type { get; construct set; }

      public MatchObject (Zeitgeist.Event event,
                          string? thumbnail_path,
                          string? icon)
      {
        Object (match_type: MatchType.GENERIC_URI,
                has_thumbnail: thumbnail_path != null,
                icon_name: icon ?? "",
                thumbnail_path: thumbnail_path ?? "");

        init_from_event (event);
      }

      private void init_from_event (Zeitgeist.Event event)
      {
        var subject = event.get_subject (0);
        this.uri = subject.get_uri ();
        var f = File.new_for_uri (this.uri);
        this.description = f.get_parse_name ();

        unowned string text = subject.get_text ();
        if (text == null || text == "")
        {
          this.title = this.description;
        }
        else
        {
          this.title = text;
        }
      }
    }

    private Zeitgeist.Index zg_index;

    construct
    {
      zg_index = new Zeitgeist.Index ();
    }

    private string interesting_attributes =
      string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                        FILE_ATTRIBUTE_STANDARD_ICON,
                        FILE_ATTRIBUTE_THUMBNAIL_PATH,
                        null);

    private async void process_results (string query,
                                        Zeitgeist.ResultSet events,
                                        Cancellable cancellable,
                                        ResultSet results,
                                        bool local_only)
    {
      Gee.Set<string> uris = new Gee.HashSet<string> ();

      var matchers = Query.get_matchers_for_query (
        query,
        MatcherFlags.NO_FUZZY | MatcherFlags.NO_PARTIAL,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var event in events)
      {
        if (event.num_subjects () <= 0) continue;
        var subject = event.get_subject (0);
        unowned string uri = subject.get_uri ();
        if (!(uri in uris))
        {
          int relevancy_penalty = Match.URI_PENALTY;
          string? thumbnail_path = null;
          string? icon = null;
          uris.add (uri);
          var f = File.new_for_uri (uri);
          if (f.is_native ())
          {
            try
            {
              // will throw error if it doesn't exist
              var fi = yield f.query_info_async (interesting_attributes,
                                                 0, 0,
                                                 cancellable);

              icon = fi.get_icon ().to_string ();
              if (fi.has_attribute (FILE_ATTRIBUTE_THUMBNAIL_PATH))
              {
                thumbnail_path =
                  fi.get_attribute_byte_string (FILE_ATTRIBUTE_THUMBNAIL_PATH);
              }
            }
            catch (Error err)
            {
              if (cancellable.is_cancelled ()) return;
              else continue; // file doesn't exist
            }
          }
          else if (local_only)
          {
            continue;
          }
          else
          {
            relevancy_penalty += 5;
            if (f.get_uri_scheme () == "data") continue;
            unowned string mimetype = subject.get_mimetype ();
            if (mimetype != null && mimetype != "")
            {
              icon = g_content_type_get_icon (mimetype).to_string ();
            }
          }
          var match_obj = new MatchObject (event,
                                           thumbnail_path,
                                           icon);
          bool match_found = false;
          foreach (var matcher in matchers)
          {
            if (matcher.key.match (match_obj.title))
            {
              results.add (match_obj, matcher.value - relevancy_penalty);
              match_found = true;
              break;
            }
          }
          if (!match_found) results.add (match_obj, 60);
        }
      }
    }

    private GenericArray<Zeitgeist.Event> create_templates (QueryFlags flags)
    {
      var templates = new GenericArray<Zeitgeist.Event> ();
      var manifestation = QueryFlags.LOCAL_ONLY in flags ?
        "!" + Zeitgeist.NFO_REMOTE_DATA_OBJECT : "";

      Zeitgeist.Event event;
      Zeitgeist.Subject subject;

      if (QueryFlags.AUDIO in flags)
      {
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation (Zeitgeist.NFO_AUDIO);
        subject.set_manifestation (manifestation);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);

        templates.add (event);
      }

      if (QueryFlags.VIDEO in flags)
      {
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation (Zeitgeist.NFO_VIDEO);
        subject.set_manifestation (manifestation);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);

        templates.add (event);
      }

      if (QueryFlags.IMAGES in flags)
      {
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation (Zeitgeist.NFO_IMAGE);
        subject.set_manifestation (manifestation);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);

        templates.add (event);
      }

      if (QueryFlags.DOCUMENTS in flags)
      {
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation (Zeitgeist.NFO_DOCUMENT);
        subject.set_manifestation (manifestation);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);

        templates.add (event);
      }

      if (QueryFlags.INTERNET in flags)
      {
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation (Zeitgeist.NFO_WEBSITE);
        subject.set_manifestation (manifestation);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);

        templates.add (event);
      }

      if (QueryFlags.UNCATEGORIZED in flags)
      {
        event = new Zeitgeist.Event ();
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_AUDIO);
        event.add_subject (subject);
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_VIDEO);
        event.add_subject (subject);
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_IMAGE);
        event.add_subject (subject);
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_DOCUMENT);
        event.add_subject (subject);
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_WEBSITE);
        event.add_subject (subject);

        // and one more subject to say that we might not want remote stuff
        if (QueryFlags.LOCAL_ONLY in flags)
        {
          subject = new Zeitgeist.Subject ();
          subject.set_manifestation (manifestation);
          event.add_subject (subject);
        }

        templates.add (event);
      }

      return templates;
    }

    public override async ResultSet? search (Query q) throws SearchError
    {
      var result = new ResultSet ();

      var timer = new Timer ();

      var templates = new PtrArray ();
      var event_templates = create_templates (q.query_type);
      if (event_templates.length == 0) return result; // nothing to search for
      for (int i=0; i<event_templates.length; i++)
      {
        templates.add (event_templates[i]);
      }

      var search_query = q.query_string.strip ();
      if (!search_query.has_suffix ("*")) search_query += "*";
      try
      {
        var rs = yield zg_index.search (search_query,
                                        new Zeitgeist.TimeRange (int64.MIN, int64.MAX),
                                        (owned) templates,
                                        0,
                                        96,
                                        Zeitgeist.ResultType.MOST_RECENT_SUBJECTS,
                                        q.cancellable);

        if (!q.is_cancelled ())
        {
          yield process_results (q.query_string, rs, q.cancellable, result,
                                 QueryFlags.LOCAL_ONLY in q.query_type);
        }
      }
      catch (Error err)
      {
        warning ("Search in Zeitgeist's index failed: %s", err.message);
      }

      q.check_cancellable ();

      debug ("ZG search took %d ms", (int)(timer.elapsed ()*1000));

      return result;
    }
  }
}
