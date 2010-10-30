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
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  /* The target of this abstract class, is to separate model/control from view. */
  /* Each IU must implement this abstract class by translating user input into actions for this class. */
  /* Here is a list of possible actions: */
  /* - update_query_flags : when user selects a new filter like "Audio", "Video", "Applications"
     - select_next_match : when user wants to select the next match in the list
     - select_prev_match : when user wants to select the prev match in the list
     - select_next_action : when user wants to select the next action in the list
     - select_prev_action : when user wants to select the prev action in the list
     - reset_search : when user hits the "Esc" button to hide Sezen2
     - set_match_search : when user writes a new string for searching matches
     - set_action_search : when user writes a new string for searching actions
     - execute : when user wants to execute the match
  Validity checks are already implemented in these methods.
  Each UI must implement four methods:
  - protected abstract void focus_match ( int index, Match? match );
    This one has to show the Match "match" (that you can find in "index" position in results list)
  - protected abstract void focus_action ( int index, Match? action );
    This one has to show the Action "action" (that you can find in "index" position in results list)
  - protected abstract void update_match_result_list (Gee.List<Match>? matches, int index, Match? match);
    This one has to update visually the result list, and then select the Match "match" in the "index" position
    The UI can choose to show the list or not.
  - protected abstract void update_action_result_list (Gee.List<Match>? actions, int index, Match? action);
    This one has to update visually the action list, and then select the Action "action" in the "index" position
    The UI can choose to show the list or not.
  */
  
  public abstract class UIInterface : GLib.Object
  {
    private const int PARTIAL_TIMEOUT = 50; //millisecond for show partial results
    private DataSink data_sink;
    private enum T 
    {
      MATCH,
      ACTION
    }
    private int focus_index[2];
    private Match? focus[2];
    private Gee.List<Match>? results[2];
    private QueryFlags qf;
    private string search[2];
    
    private Source partial_result_timer;
    
    construct
    {
      data_sink = new DataSink();
      reset_search (false);
    }
    /* UI must do the following things */
    protected abstract void focus_match ( int index, Match? match );
    protected abstract void focus_action ( int index, Match? action );
    protected abstract void update_match_result_list (Gee.List<Match>? matches, int index, Match? match);
    protected abstract void update_action_result_list (Gee.List<Match>? actions, int index, Match? action);

    /* What this abstract class offer */
    protected void update_query_flags (QueryFlags flags)
    {
      if (qf == flags)
        return;
      qf = flags;
      focus_index = {0, 0};
      focus = {null, null};
      results = {null, null};
      search[T.ACTION] = "";
      search_for_matches ();
    }
    protected bool select_next_match ()
    {
      return select_match_next_prev (true);
    }
    protected bool select_prev_match ()
    {
      return select_match_next_prev (false);
    }
    private bool select_match_next_prev (bool next)
    {
      if (!util_select_prev_next (T.MATCH, next))
        return false;
      focus_match (focus_index[T.MATCH], focus[T.MATCH]);
      search_for_actions ();
      return true;
    }
    protected bool select_next_action ()
    {
      if (!util_select_prev_next (T.ACTION, true))
        return false;
      focus_action (focus_index[T.ACTION], focus[T.ACTION]);
      return true;
    }
    protected bool select_prev_action ()
    {
      if (!util_select_prev_next (T.ACTION, false))
        return false;
      focus_action (focus_index[T.ACTION], focus[T.ACTION]);
      return true;
    }
    private bool util_select_prev_next (T t, bool next)
    {
      if (next)
      {
        if (results[t] == null || (focus_index[t] + 1) >= results[t].size)
          return false;
        focus_index[t] += 1;
      }
      else
      {
        if (results[t] == null || focus_index[t] == 0 || results[t].size == 0)
          return false;
        focus_index[t] -= 1;
      }
      focus[t] = results[t].get (focus_index[t]);
      return true;      
    }    
    protected void reset_search (bool notify = true, bool reset_flags = true)
    {
      focus_index = {0, 0};
      focus = {null, null};
      results = {null, null};
      search = {"", ""};
      if (reset_flags)
        qf = QueryFlags.ALL;
      if (notify)
      {
        update_match_result_list (null, 0, null);
        update_action_result_list (null, 0, null);
      }
    }
    
    protected bool is_search_empty ()
    {
      return search[T.MATCH].length == 0;
    }
    
    protected string get_match_search () {return search[T.MATCH];}
    protected void set_match_search (string pattern)
    {
      if (search[T.MATCH] == pattern)
        return;
      search[T.MATCH] = pattern;
      search_for_matches ();
    }
    protected string get_action_search () {return search[T.ACTION];}
    protected void set_action_search (string pattern)
    {
      if (search[T.ACTION] == pattern)
        return;
      search[T.ACTION] = pattern;
      search_for_actions ();
    }
    
    protected Gee.List<Match>? get_action_results () {return results[T.ACTION];}
    protected Gee.List<Match>? get_match_results () {return results[T.MATCH];}
    protected void get_action_focus (out int index, out Match? action) {index = focus_index[T.ACTION]; action = focus[T.ACTION];}
    protected void get_match_focus (out int index, out Match? match) {index = focus_index[T.MATCH]; match = focus[T.MATCH];}
    
    private void search_for_matches ()
    {
      /* STOP current search */
      if (partial_result_timer != null)
        partial_result_timer.destroy ();
      data_sink.cancel_search ();

      if (search[T.MATCH] == "")
      {
        reset_search (true, false);
        return;
      }
      focus_index[T.MATCH] = 0;
      debug ("Searching for : %s", search[T.MATCH]);
      partial_result_timer = new TimeoutSource(PARTIAL_TIMEOUT);
      partial_result_timer.set_callback(() => {
          _send_partial_results ();
          return false;
      });
      partial_result_timer.attach(null);

      data_sink.search (search[T.MATCH], qf, _search_ready);
    }
    
    private void _send_partial_results ()
    {
      results[T.MATCH] = data_sink.get_partial_results ();
      if (results[T.MATCH].size > 0)
      {
        focus[T.MATCH] = results[T.MATCH].first();
      }
      else
      {
        focus[T.MATCH] = null;
      }
      /* If we are here, we are searching for Matches */
      update_match_result_list (results[T.MATCH], focus_index[T.MATCH], focus[T.MATCH]);
      /* Send also actions */
      search_for_actions ();
    }
    
    private void _search_ready (GLib.Object? obj, AsyncResult res)
    {
      if (partial_result_timer != null)
      {
        partial_result_timer.destroy ();
      }
      try
      {
        results[T.MATCH] = data_sink.search.end (res);
        if (results[T.MATCH].size > 0)
        {
          focus[T.MATCH] = results[T.MATCH].get (focus_index[T.MATCH]);
        }
        else
        {
          focus[T.MATCH] = null;
        }
        /* If we are here, we are searching for Matches */
        update_match_result_list (results[T.MATCH], focus_index[T.MATCH], focus[T.MATCH]);
        /* Send also actions */
        search_for_actions ();
      }
      catch (SearchError err)
      {
        // most likely cancelled
      }
    }
    
    private void search_for_actions ()
    {
      if (focus[T.MATCH] == null)
      {
        update_action_result_list (null, 0, null);
        return;
      }
      results[T.ACTION] = data_sink.find_action_for_match (focus[T.MATCH], search[T.ACTION]);
      if (results[T.ACTION].size > 0)
      {
        focus[T.ACTION] = results[T.ACTION].first();
      }
      else
      {
        focus[T.ACTION] = null;
      }
      focus_index[T.ACTION] = 0;
      update_action_result_list (results[T.ACTION], focus_index[T.ACTION], focus[T.ACTION]);
    }
    
    protected bool execute ()
    {
      if (focus[T.MATCH] == null || focus[T.ACTION] == null)
        return false;
      focus[T.ACTION].execute (focus[T.MATCH]);
      return true;
    }
  }
}
