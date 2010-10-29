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
  [Flags]
  public enum QueryFlags
  {
    LOCAL_ONLY    = 1 << 0,

    APPLICATIONS  = 1 << 1,
    ACTIONS       = 1 << 2,
    AUDIO         = 1 << 3,
    VIDEO         = 1 << 4,
    DOCUMENTS     = 1 << 5,
    IMAGES        = 1 << 6,
    INTERNET      = 1 << 7,

    UNCATEGORIZED = 1 << 15,

    LOCAL_CONTENT = 0xFF | QueryFlags.UNCATEGORIZED,
    ALL           = 0xFE | QueryFlags.UNCATEGORIZED
  }
  
  [Flags]
  public enum MatcherFlags
  {
    NO_REVERSED   = 1 << 0,
    NO_SUBSTRING  = 1 << 1,
    NO_PARTIAL    = 1 << 2,
    NO_FUZZY      = 1 << 3
  }

  public struct Query
  {
    string query_string;
    string query_string_folded;
    Cancellable cancellable;
    QueryFlags query_type;

    public Query (string query, QueryFlags flags = QueryFlags.LOCAL_CONTENT)
    {
      this.query_string = query;
      this.query_string_folded = query.casefold ();
      this.query_type = flags;
    }

    public bool is_cancelled ()
    {
      return cancellable.is_cancelled ();
    }

    public void check_cancellable () throws SearchError
    {
      if (cancellable.is_cancelled ())
      {
        throw new SearchError.SEARCH_CANCELLED ("Cancelled");
      }
    }

    public static Gee.List<Gee.Map.Entry<Regex, int>>
    get_matchers_for_query (string query,
                            MatcherFlags match_flags = 0,
                            RegexCompileFlags flags = RegexCompileFlags.OPTIMIZE)
    {
      /* create a couple of regexes and try to help with matching
       * match with these regular expressions (with descending score):
       * 1) ^query$
       * 2) ^query
       * 3) \bquery
       * 4) split to words and seach \bword1.+\bword2 (if there are 2+ words)
       * 5) query
       * 6) split to characters and search \bq.+\bu.+\be.+\br.+\by
       * 7) split to characters and search \bq.*u.*e.*r.*y
       *
       * The set of returned regular expressions depends on MatcherFlags.
       */

      var results = new Gee.HashMap<Regex, int> ();
      Regex re;

      try
      {
        re = new Regex ("^(%s)$".printf (Regex.escape_string (query)), flags);
        results[re] = 100;
      }
      catch (RegexError err)
      {
      }

      try
      {
        re = new Regex ("^(%s)".printf (Regex.escape_string (query)), flags);
        results[re] = 90;
      }
      catch (RegexError err)
      {
      }

      try
      {
        re = new Regex ("\\b(%s)".printf (Regex.escape_string (query)), flags);
        results[re] = 85;
      }
      catch (RegexError err)
      {
      }

      // split to individual chars
      string[] individual_words = Regex.split_simple ("\\s+", query.strip ());
      if (individual_words.length >= 2)
      {
        string[] escaped_words = {};
        foreach (unowned string word in individual_words)
        {
          escaped_words += Regex.escape_string (word);
        }
        string pattern = "\\b(%s)".printf (string.joinv (").+\\b(",
                                                         escaped_words));

        try
        {
          re = new Regex (pattern, flags);
          results[re] = 80;
        }
        catch (RegexError err)
        {
        }

        // FIXME: do something generic here
        if (!(MatcherFlags.NO_REVERSED in match_flags))
        {
          if (escaped_words.length == 2)
          {
            var reversed = "\\b(%s)".printf (string.join (").+\\b(",
                                                        escaped_words[1],
                                                        escaped_words[0],
                                                        null));
            try
            {
              re = new Regex (reversed, flags);
              results[re] = 78;
            }
            catch (RegexError err)
            {
            }
          }
          else
          {
            // not too nice, but is quite fast to compute
            var orred = "\\b((?:%s))".printf (string.joinv (")|(?:", escaped_words));
            var any_order = "";
            for (int i=0; i<escaped_words.length; i++)
            {
              bool is_last = i == escaped_words.length - 1;
              any_order += orred;
              if (!is_last) any_order += ".+";
            }
            try
            {
              re = new Regex (any_order, flags);
              results[re] = 76;
            }
            catch (RegexError err)
            {
            }
          }
        }
      }
      
      if (!(MatcherFlags.NO_SUBSTRING in match_flags))
      {
        try
        {
          re = new Regex ("(%s)".printf (Regex.escape_string (query)), flags);
          results[re] = 75;
        }
        catch (RegexError err)
        {
        }
      }

      // split to individual chars
      string[] individual_chars = Regex.split_simple ("\\s*", query);
      string[] escaped_chars = {};
      foreach (unowned string word in individual_chars)
      {
        escaped_chars += Regex.escape_string (word);
      }

      if (!(MatcherFlags.NO_PARTIAL in match_flags) &&
          individual_chars.length <= 5)
      {
        string pattern = "\\b(%s)".printf (string.joinv (").+\\b(",
                                                         escaped_chars));
        try
        {
          re = new Regex (pattern, flags);
          results[re] = 70;
        }
        catch (RegexError err)
        {
        }
      }

      if (!(MatcherFlags.NO_FUZZY in match_flags))
      {
        string pattern = "\\b(%s)".printf (string.joinv (").*(",
                                                         escaped_chars));
        try
        {
          re = new Regex (pattern, flags);
          results[re] = 50;
        }
        catch (RegexError err)
        {
        }
      }

      var sorted_results = new Gee.LinkedList<Gee.Map.Entry<Regex, int>> ();
      var entries = results.entries;
      // FIXME: why it doesn't work without this?
      sorted_results.set_data ("entries-ref", entries);
      sorted_results.add_all (entries);
      sorted_results.sort ((a, b) =>
      {
        unowned Gee.Map.Entry<Regex, int> e1 = (Gee.Map.Entry<Regex, int>) a;
        unowned Gee.Map.Entry<Regex, int> e2 = (Gee.Map.Entry<Regex, int>) b;
        return e2.value - e1.value;
      });

      return sorted_results;
    }
  }
}

