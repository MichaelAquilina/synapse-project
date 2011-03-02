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
  public class ZeitgeistPlugin: Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      zg_log = new Zeitgeist.Log ();
      zg_index = new Zeitgeist.Index ();
    }

    public void deactivate ()
    {
      
    }

    private const string UNIQUE_NAME = "org.gnome.zeitgeist.Engine";
    private class MatchObject: Object, 
      Match, UriMatch, ApplicationMatch, ExtendedInfo
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      // for ApplicationMatch
      public AppInfo? app_info { get; set; }
      public bool needs_terminal { get; set; }
      public string? filename { get; construct set; }

      // for UriMatch
      public string uri { get; set; }
      public QueryFlags file_type { get; set; }
      public string mime_type { get; set; }
      
      // for ExtendedInfo
      public string? extended_info { get; set; default = null; }

      public MatchObject (Zeitgeist.Event event,
                          string? thumbnail_path,
                          string? icon,
                          bool is_application = false)
      {
        Object (match_type: MatchType.GENERIC_URI,
                has_thumbnail: thumbnail_path != null,
                icon_name: icon ?? "",
                thumbnail_path: thumbnail_path ?? "");

        if (!is_application) init_from_event (event);
        else init_from_app_event (event);
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
        
        this.mime_type = subject.get_mimetype ();

        unowned string interpretation = subject.get_interpretation ();
        if (Zeitgeist.Symbol.is_a (interpretation, Zeitgeist.NFO_AUDIO))
        {
          this.file_type = QueryFlags.AUDIO;
        }
        else if (Zeitgeist.Symbol.is_a (interpretation, Zeitgeist.NFO_VIDEO))
        {
          this.file_type = QueryFlags.VIDEO;
        }
        else if (Zeitgeist.Symbol.is_a (interpretation, Zeitgeist.NFO_IMAGE))
        {
          this.file_type = QueryFlags.IMAGES;
        }
        else if (Zeitgeist.Symbol.is_a (interpretation, Zeitgeist.NFO_DOCUMENT))
        {
          this.file_type = QueryFlags.DOCUMENTS;
        }
        else if (Zeitgeist.Symbol.is_a (interpretation, Zeitgeist.NFO_WEBSITE))
        {
          this.file_type = QueryFlags.INTERNET;
        }
        else
        {
          this.file_type = QueryFlags.UNCATEGORIZED;
        }
      }

      private void init_from_app_event (Zeitgeist.Event event)
      {
        this.file_type = QueryFlags.UNCATEGORIZED;
        this.match_type = MatchType.APPLICATION;
        var subject = event.get_subject (0);
        this.uri = subject.get_uri ();

        var dfs = DesktopFileService.get_default ();
        var dfi = dfs.get_desktop_file_for_id (uri.substring (14));

        this.title = dfi.name;
        this.icon_name = dfi.icon_name;
        this.description = dfi.comment;
        this.needs_terminal = dfi.needs_terminal;
        this.filename = dfi.filename;
      }
      
      public void init_extended_info_from_event (Zeitgeist.Event event)
      {
        var now = Zeitgeist.Timestamp.now ();
        var delta = now - event.get_timestamp ();
        if (delta < Zeitgeist.Timestamp.MINUTE * 2)
        {
          extended_info = _("few moments ago");
        }
        else if (delta < Zeitgeist.Timestamp.HOUR)
        {
          int mins = (int) (delta / Zeitgeist.Timestamp.MINUTE);
          extended_info = ngettext ("%d minute ago", "%d minutes ago", mins).printf (mins);
        }
        else if (delta < Zeitgeist.Timestamp.DAY * 2)
        {
          int hours = (int) (delta / Zeitgeist.Timestamp.HOUR);
          extended_info = ngettext ("%d hour ago", "%d hours ago", hours).printf (hours);
        }
        else if (delta < Zeitgeist.Timestamp.WEEK * 2)
        {
          int days = (int) (delta / Zeitgeist.Timestamp.DAY);
          extended_info = ngettext ("%d day ago", "%d days ago", days).printf (days);
        }
        else if (delta < Zeitgeist.Timestamp.YEAR)
        {
          int weeks = (int) (delta / Zeitgeist.Timestamp.WEEK);
          extended_info = ngettext ("%d week ago", "%d weeks ago", weeks).printf (weeks);
        }
        else
        {
          extended_info = "long time ago";
        }
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (ZeitgeistPlugin),
        "Zeitgeist",
        _ ("Search various items logged by Zeitgeist."),
        "zeitgeist",
        register_plugin,
        DBusService.get_default ().name_is_activatable (UNIQUE_NAME),
        _ ("Zeitgeist is not installed")
      );
    }

    static construct
    {
      register_plugin ();
    }

    private Zeitgeist.Index zg_index;
    private Zeitgeist.Log zg_log;

    construct
    {
    }

    private int compute_relevancy (string uri, int base_relevancy)
    {
      var rs = RelevancyService.get_default ();
      float pop = rs.get_uri_popularity (uri);

      return RelevancyService.compute_relevancy (base_relevancy, pop);
    }
    
    private static void update_min_max (string uri, ref long minimum, ref long maximum)
    {
#if VALA_0_12
      long len = uri.length;
#else
      long len = (long) uri.size ();
#endif
      if (len > maximum) maximum = len;
      if (len < minimum) minimum = len;
    }

    private string interesting_attributes =
      string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                        FILE_ATTRIBUTE_STANDARD_ICON,
                        FILE_ATTRIBUTE_THUMBNAIL_PATH,
                        FILE_ATTRIBUTE_STANDARD_IS_HIDDEN,
                        null);

    private async void process_results (string query,
                                        Zeitgeist.ResultSet events,
                                        Cancellable cancellable,
                                        ResultSet real_results,
                                        bool local_only)
    {
      Gee.Set<string> uris = new Gee.HashSet<string> ();

      var matchers = Query.get_matchers_for_query (
        query,
        MatcherFlags.NO_FUZZY | MatcherFlags.NO_PARTIAL,
        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      // temp results
      var results = new ResultSet ();
      long minimum = long.MAX;
      long maximum = 0;

      foreach (var event in events)
      {
        if (event.num_subjects () <= 0) continue;
        var subject = event.get_subject (0);
        unowned string uri = subject.get_uri ();
        if (uri == null || uri == "") continue;
        // make sure we don't add the same uri twice
        if (!(uri in uris))
        {
          int relevancy_penalty = Match.Score.URI_PENALTY;
          string? thumbnail_path = null;
          string? icon = null;
          uris.add (uri);
          var f = File.new_for_uri (uri);
          // this screws up gio, we better skip it
          if (f.get_uri_scheme () == "data") continue;
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
              // decrease relevancy of hidden files
              if (fi.get_is_hidden ())
              {
                relevancy_penalty += Match.Score.INCREMENT_MEDIUM;
              }
            }
            catch (Error err)
            {
              if (cancellable.is_cancelled ()) return;
              else continue; // file doesn't exist
            }
          }
          else if (uri.has_prefix ("note://tomboy/"))
          {
            // special case tomboy notes - we need to make sure the notes weren't deleted
            string note_filename = uri.substring (14) + ".note";
            string note_path = Path.build_filename (Environment.get_user_data_dir (),
                                                    "tomboy", note_filename);
            var note_f = File.new_for_path (note_path);
            bool exists = yield Utils.query_exists_async (note_f);
            
            if (cancellable.is_cancelled ()) return;
            else if (!exists) continue;
            
            icon = g_content_type_get_icon ("application/x-note").to_string ();
          }
          else if (local_only)
          {
            continue;
          }
          else // non native (mostly remote uris)
          {
            relevancy_penalty += Match.Score.INCREMENT_SMALL;
            unowned string mimetype = subject.get_mimetype ();
            if (mimetype != null && mimetype != "")
            {
              icon = g_content_type_get_icon (mimetype).to_string ();
            }
            // we want to increase relevancy of shorter URL, so we'll do this
            if (uri.has_prefix ("http"))
            {
              update_min_max (uri, ref minimum, ref maximum);
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
              int relevancy = compute_relevancy (uri, matcher.value - relevancy_penalty);
              results.add (match_obj, relevancy);
              match_found = true;
              break;
            }
          }
          if (!match_found) results.add (match_obj, Match.Score.POOR + Match.Score.INCREMENT_MINOR);
        }
      }
      
      foreach (var entry in results.entries)
      {
        var mo = entry.key as MatchObject;
        if (mo.uri != null && mo.uri.has_prefix ("http") && minimum != maximum)
        {
#if VALA_0_12
          long len = mo.uri.length;
#else
          long len = (long) mo.uri.size ();
#endif
          float mult = (len - minimum) / (float)(maximum - minimum);
          int adjusted_relevancy = entry.value - (int)(mult * Match.Score.INCREMENT_MINOR);
          real_results.add (mo, adjusted_relevancy);
        }
        else
        {
          real_results.add (mo, entry.value);
        }
      }
    }

    private async void process_recent_results (Zeitgeist.ResultSet events,
                                               Cancellable cancellable,
                                               ResultSet results,
                                               bool local_only)
    {
      Gee.Set<string> uris = new Gee.HashSet<string> ();
      
      uint events_size = events.size ();
      uint event_index = 0;

      foreach (var event in events)
      {
        event_index++;
        if (event.num_subjects () <= 0) continue;
        var subject = event.get_subject (0);
        unowned string uri = subject.get_uri ();
        if (!(uri in uris))
        {
          bool is_application = uri.has_prefix ("application://");
          int relevancy_penalty = Match.Score.URI_PENALTY;
          string? thumbnail_path = null;
          string? icon = null;
          uris.add (uri);
          var f = File.new_for_uri (uri);
          if (f.get_uri_scheme () == "data") continue;
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
              // decrease relevancy of hidden files
              if (fi.get_is_hidden ())
              {
                relevancy_penalty += Match.Score.INCREMENT_MEDIUM;
              }
            }
            catch (Error err)
            {
              if (cancellable.is_cancelled ()) return;
              else continue; // file doesn't exist
            }
          }
          else if (local_only && !is_application)
          {
            continue;
          }
          else if (is_application)
          {
            var dfs = DesktopFileService.get_default ();
            if (dfs.get_desktop_file_for_id (uri.substring (14)) == null) continue;
          }
          else
          {
            relevancy_penalty += Match.Score.INCREMENT_SMALL;
            unowned string mimetype = subject.get_mimetype ();
            if (mimetype != null && mimetype != "")
            {
              icon = g_content_type_get_icon (mimetype).to_string ();
            }
          }

          var match_obj = new MatchObject (event,
                                           thumbnail_path,
                                           icon,
                                           is_application);
          match_obj.init_extended_info_from_event (event);

          int relevancy = (int) ((events_size - event_index) / 
            (float) events_size * Match.Score.HIGHEST);
          results.add (match_obj, relevancy);
        }
      }
    }

    private GenericArray<Zeitgeist.Event> create_templates (QueryFlags flags)
    {
      var templates = new GenericArray<Zeitgeist.Event> ();
      var manifestation = QueryFlags.INCLUDE_REMOTE in flags ?
        "" : "!" + Zeitgeist.NFO_REMOTE_DATA_OBJECT;

      Zeitgeist.Event event;
      Zeitgeist.Subject subject;

      var flags_intersect = flags & QueryFlags.LOCAL_CONTENT;
      if (flags_intersect == QueryFlags.LOCAL_CONTENT) // "All" category
      {
        subject = new Zeitgeist.Subject ();
        subject.set_manifestation (manifestation);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);
        /* ignore some results */
        // bzr plugin logs these, and we probably don't want to search
        //   in commit messages
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_FOLDER);
        event.add_subject (subject);
        // according to seif,these results arent wanted (because of App plugin?)
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation ("!" + Zeitgeist.NFO_SOFTWARE);
        event.add_subject (subject);

        templates.add (event);

        return templates; // this is the only template we need
      }
      
      if (QueryFlags.APPLICATIONS in flags)
      {
        subject = new Zeitgeist.Subject ();
        subject.set_interpretation (Zeitgeist.NFO_SOFTWARE);
        event = new Zeitgeist.Event ();
        event.add_subject (subject);

        templates.add (event);
      }

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
        subject.set_interpretation ("!" + Zeitgeist.NFO_SOFTWARE);
        event.add_subject (subject);
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
        if (!(QueryFlags.INCLUDE_REMOTE in flags))
        {
          subject = new Zeitgeist.Subject ();
          subject.set_manifestation (manifestation);
          event.add_subject (subject);
        }

        templates.add (event);
      }

      return templates;
    }
    
    public bool handles_empty_query ()
    {
      return true;
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      var search_query = q.query_string.strip ();
      bool empty_query = search_query == "";
      // allow application searching only for empty queries
      if (!empty_query) q.query_type = q.query_type & (~QueryFlags.APPLICATIONS);

      var timer = new Timer ();

      var templates = new PtrArray ();
      var event_templates = create_templates (q.query_type);
      if (event_templates.length == 0) return null; // nothing to search for
      for (int i=0; i<event_templates.length; i++)
      {
        templates.add (event_templates[i]);
      }

      var result = new ResultSet ();

      try
      {
        Zeitgeist.ResultSet rs;
        bool only_local = !(QueryFlags.INCLUDE_REMOTE in q.query_type);
        if (empty_query)
        {
          // special case empty searches
          int64 start_ts = Zeitgeist.Timestamp.now () - Zeitgeist.Timestamp.WEEK * 4;
          rs = yield zg_log.find_events (new Zeitgeist.TimeRange (start_ts, int64.MAX),
                                         (owned) templates,
                                         Zeitgeist.StorageState.ANY,
                                         q.max_results,
                                         Zeitgeist.ResultType.MOST_RECENT_SUBJECTS,
                                         q.cancellable);

          if (!q.is_cancelled ())
          {
            yield process_recent_results (rs, q.cancellable, result, only_local);
          }
        }
        else
        {
          string[] words = Regex.split_simple ("\\s+", search_query);
          search_query = "(%s*)".printf (string.joinv ("* ", words));
          rs = yield zg_index.search (search_query,
                                      new Zeitgeist.TimeRange (int64.MIN, int64.MAX),
                                      (owned) templates,
                                      0,
                                      q.max_results,
                                      Zeitgeist.ResultType.MOST_RECENT_SUBJECTS,
                                      q.cancellable);

          if (!q.is_cancelled ())
          {
            yield process_results (q.query_string, rs, q.cancellable, result,
                                   only_local);
          }
        }
      }
      catch (Error err)
      {
        if (!q.is_cancelled ())
        {
          // we don't care about message about being cancelled
          Utils.Logger.warning (this, "Zeitgeist search failed: %s", err.message);
        }
      }

      q.check_cancellable ();

      Utils.Logger.debug (this, "search took %d ms", (int)(timer.elapsed ()*1000));

      return result;
    }
  }
}
