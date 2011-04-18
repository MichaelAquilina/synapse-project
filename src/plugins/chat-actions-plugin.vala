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
  public class ChatActions: Object, Activatable, ActionProvider
  {
    public bool enabled { get; set; default = true; }

    public void activate ()
    {
      
    }

    public void deactivate ()
    {
      
    }
    
    private abstract class ContactAction: Object, Match
    {
      // from Match interface
      public string title { get; construct set; }
      public string description { get; set; }
      public string icon_name { get; construct set; }
      public bool has_thumbnail { get; construct set; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }
      public int default_relevancy { get; set; }
      
      public virtual int get_relevancy ()
      {
        return default_relevancy;
      }
      
      public virtual void execute (Match? match) {
        
      }
    }
    
    private class OpenChat: ContactAction
    {
      public OpenChat ()
      {
        Object (title: _ ("Open chat"),
                description: _ ("Open a chat with selected contact"),
                icon_name: "empathy", has_thumbnail: false,
                match_type: MatchType.ACTION,
                default_relevancy: Match.Score.EXCELLENT);
      }
      
      public override void execute (Match? match)
      {
        ContactMatch? cm = match as ContactMatch;
        if ( match == null ) return;
        cm.open_chat ();
      }
    }
    
    static void register_plugin ()
    {
      DataSink.PluginRegistry.get_default ().register_plugin (
        typeof (ChatActions),
        _ ("Chat actions"),
        _ ("Open chat, or send a message with your favorite IM"),
        "empathy",
        register_plugin
      );
    }
    
    static construct
    {
      register_plugin ();
    }

    private Gee.List<ContactAction> actions;

    construct
    {
      actions = new Gee.ArrayList<ContactAction> ();

      actions.add (new OpenChat ());
    }

    public ResultSet? find_for_match (Query query, Match match)
    {
      bool query_empty = query.query_string == "";
      var results = new ResultSet ();
      
      if (query_empty)
      {
        foreach (var action in actions)
        {
          if (match is ContactMatch)
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
          if (!(match is ContactMatch)) continue;
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
