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
  public enum MatchType
  {
    UNKNOWN = 0,
    DESKTOP_ENTRY,
    GENERIC_URI,
    ACTION
  }

  public interface Match: Object
  {
    public const int URI_PENALTY = 10;
    
    // properties
    public abstract string title { get; construct set; }
    public abstract string description { get; set; }
    public abstract string icon_name { get; construct set; }
    public abstract bool has_thumbnail { get; construct set; }
    public abstract string thumbnail_path { get; construct set; }
    public abstract string uri { get; set; }
    public abstract MatchType match_type { get; construct set; }

    public virtual void execute (Match? match)
    {
      warning ("%s.execute () is not implemented", this.get_type ().name ());
    }
  }
  
  public class DefaultMatch: Object, Match
  {
    public string title { get; construct set; }
    public string description { get; set; }
    public string icon_name { get; construct set; }
    public bool has_thumbnail { get; construct set; }
    public string thumbnail_path { get; construct set; }
    public string uri { get; set; }
    public MatchType match_type { get; construct set; }
    
    public DefaultMatch (string query_string)
    {
      Object (title: query_string, description: "", has_thumbnail: false,
              icon_name: "unknown", match_type: MatchType.UNKNOWN);
    }
  }
}

