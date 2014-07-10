/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *             Alberto Aldegheri <albyrock87+dev@gmail.com>
 */

namespace Synapse
{
  public enum MatchScore
  {
    INCREMENT_MINOR = 2000,
    INCREMENT_SMALL = 5000,
    INCREMENT_MEDIUM = 10000,
    INCREMENT_LARGE = 20000,
    URI_PENALTY = 15000,

    POOR = 50000,
    BELOW_AVERAGE = 60000,
    AVERAGE = 70000,
    ABOVE_AVERAGE = 75000,
    GOOD = 80000,
    VERY_GOOD = 85000,
    EXCELLENT = 90000,

    HIGHEST = 100000
  }

  public abstract class Match : Object
  {
    public signal void executed ();

    // properties
    public string title { get; construct set; }
    public string description { get; construct set; }
    public string icon_name { get; construct set; }
    public bool has_thumbnail { get; construct set; }
    public string thumbnail_path { get; construct set; }

    public virtual void execute (Match match)
    {
      critical ("execute () is not implemented");
    }

    public virtual void execute_with_target (Match source, Match? target = null)
    {
      if (target == null)
        execute (source);
      else
        critical ("execute_with_target () is not implemented");
    }

    public virtual bool needs_target ()
    {
      return false;
    }

    public virtual QueryFlags target_flags ()
    {
      return QueryFlags.ALL;
    }
  }

  public abstract class ActionMatch : Match
  {
    public abstract void do_action ();
  }

  public class ApplicationMatch : Match
  {
    public AppInfo? app_info { get; set; }
    public bool needs_terminal { get; set; }
    public string? filename { get; construct set; }

    public ApplicationMatch ()
    {
      Object (has_thumbnail : false,
              icon_name : "",
              thumbnail_path : "");
    }
  }

  public class UriMatch : Match
  {
    public string uri { get; set; }
    public QueryFlags file_type { get; set; }
    public string mime_type { get; set; }

    public UriMatch ()
    {
      Object (has_thumbnail : false,
              icon_name : "",
              thumbnail_path : "");
    }
  }

  public abstract class ContactMatch : Match
  {
    public abstract void send_message (string message, bool present);
    public abstract void open_chat ();
  }

  public interface ExtendedInfo
  {
    public abstract string? extended_info { get; set; }
  }

  public enum TextOrigin
  {
    UNKNOWN,
    CLIPBOARD
  }

  public abstract class TextMatch : Match
  {
    public TextOrigin text_origin { get; construct; }

    public abstract string get_text ();
  }

  public abstract class SearchMatch : Match, SearchProvider
  {
    public Match search_source { get; set; }

    public abstract async Gee.List<Synapse.Match> search (string query, Synapse.QueryFlags flags, Synapse.ResultSet? dest_result_set, GLib.Cancellable? cancellable = null) throws Synapse.SearchError;
  }

  public class UnknownMatch : Match
  {
    public UnknownMatch (string query_string)
    {
      Object (title: query_string, description: "", has_thumbnail: false,
              icon_name: "unknown");
    }
  }
}

