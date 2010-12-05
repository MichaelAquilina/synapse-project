/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

using Gee;

namespace Synapse.Gui
{
  /* The target of this abstract class, is to separate model/control from view. */
  /* Each IU must implement this abstract class by translating user input into actions for this class. */
  /* Here is a list of possible actions: */
  /* - update_query_flags : when user selects a new filter like "Audio", "Video", "Applications"
     - select_next_match : when user wants to select the next match in the list
     - select_prev_match : when user wants to select the prev match in the list
     - select_next_action : when user wants to select the next action in the list
     - select_prev_action : when user wants to select the prev action in the list
     - reset_search : when user hits the "Esc" button to hide Synapse2
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
  - protected abstract void set_throbber_visible (bool visible);
    This one is to notify the user that search is not yet completed
  */
  public enum CommandTypes
  {
    INVALID_COMMAND,
    SEARCH_DELETE_CHAR,
    NEXT_RESULT,
    PREV_RESULT,
    NEXT_CATEGORY,
    PREV_CATEGORY,
    SWITCH_SEARCH_TYPE,
    EXECUTE,
    NEXT_PAGE,
    PREV_PAGE,
    FIRST_RESULT,
    LAST_RESULT,
    CLEAR_SEARCH_OR_HIDE
  }

  public abstract class UIInterface : Object
  {
    private const int PARTIAL_TIMEOUT = 100;
    public DataSink data_sink { get; construct; }
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
    private Cancellable current_cancellable;
    private bool partial_result_sent;
    private Gee.Map<uint, CommandTypes> command_map;
    private bool search_with_empty;
    private bool handle_empty;
    
    protected static string SEARCHING;
    protected static string NO_RESULTS;
    protected static string NO_RECENT_ACTIVITIES;
    protected static string TYPE_TO_SEARCH;
    protected static string DOWN_TO_SEE_RECENT;
    
    private uint tid; //for timer
    
    static construct
    {
      SEARCHING = _("Searching...");
      NO_RESULTS = _("No results found.");
      NO_RECENT_ACTIVITIES = _("No recent activities found.");
      TYPE_TO_SEARCH = _("Type to search...");
      DOWN_TO_SEE_RECENT = "";
    }
    construct
    {
      command_map = new Gee.HashMap<uint, CommandTypes> ();
      search_with_empty = false;
      init_default_command_map ();
      tid = 0;
      partial_result_sent = false;
      current_cancellable = new Cancellable ();
      reset_search (false);
      
      /* Handle ZG plugin to set the handle_empty property*/
      var plugin = data_sink.get_plugin("SynapseZeitgeistPlugin");
      if (plugin != null)
      {
        plugin_registered_handler (plugin);
      }
      data_sink.plugin_registered.connect (plugin_registered_handler);
      update_handle_empty ();
    }
    private void plugin_registered_handler (DataPlugin plugin)
    {
      if (plugin.get_type () == typeof (ZeitgeistPlugin))
      {
        plugin.notify["enabled"].connect (update_handle_empty);
        update_handle_empty ();
      }
    }
    /* UI must do the following things */
    public abstract void show ();
    public abstract void hide ();
    public abstract void show_hide_with_time (uint32 timestamp);
    public signal void show_settings_clicked ();

    protected abstract void focus_match ( int index, Match? match );
    protected abstract void focus_action ( int index, Match? action );
    protected abstract void update_match_result_list (Gee.List<Match>? matches, int index, Match? match);
    protected abstract void update_action_result_list (Gee.List<Match>? actions, int index, Match? action);
    protected abstract void set_throbber_visible (bool visible);

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
    protected bool select_first_last_match (bool first)
    {
      return util_select_first_last (first, T.MATCH);
    }
    protected bool select_first_last_action (bool first)
    {
      return util_select_first_last (first, T.ACTION);
    }
    private bool util_select_first_last (bool first, T t)
    {
      if (results[t] == null || results[t].size == 0)
        return false;
      int newpos = first ? 0 : results[t].size - 1;
      if (newpos == focus_index[t]) return false;
      focus_index[t] = newpos;
      focus[t] = results[t].get (focus_index[t]);
      if (t == T.MATCH)
      {
        focus_match (focus_index[t], focus[t]);
        search_for_actions ();
      }
      else
        focus_action (focus_index[t], focus[t]);
      return true;
    }
    protected bool move_selection_action (int delta)
    {
      return move_selection (T.ACTION, delta);
    }
    protected bool move_selection_match (int delta)
    {
      return move_selection (T.MATCH, delta);
    }
    private bool move_selection (T t, int delta)
    {
      if (results[t] == null || results[t].size == 0)
        return false;
      if (delta > 0)
      {
        if (focus_index[t] == results[t].size - 1)
          return false;
        focus_index[t] = int.min (focus_index[t] + delta, results[t].size - 1);
      }
      else
      {
        if (focus_index[t] == 0)
          return false;
        focus_index[t] = int.max (focus_index[t] + delta, 0);
      }
      focus[t] = results[t].get (focus_index[t]);
      if (t == T.MATCH)
      {
        focus_match (focus_index[t], focus[t]);
        search_for_actions ();
      }
      else
        focus_action (focus_index[t], focus[t]);
      return true;
    }
    protected void reset_search (bool notify = true, bool reset_flags = true)
    {
      if (tid != 0)
      {
        Source.remove (tid);
        tid = 0;
      }
      current_cancellable.cancel ();
      partial_result_sent = false;
      search_with_empty = false;
      focus_index = {0, 0};
      focus = {null, null};
      results = {null, null};
      search = {"", ""};
      if (reset_flags)
        qf = QueryFlags.ALL;
      if (notify)
      {
        set_throbber_visible (false);
        update_match_result_list (null, 0, null);
        update_action_result_list (null, 0, null);
      }
    }
    
    private void update_handle_empty ()
    {
      var plugin = data_sink.get_plugin("SynapseZeitgeistPlugin");
      handle_empty = plugin != null && plugin.enabled;
      DOWN_TO_SEE_RECENT = handle_empty ? _("...or press down key to browse recent activities") : "";
      handle_empty_updated ();
    }
    protected virtual void handle_empty_updated () {}
    
    protected bool is_search_empty ()
    {
      return search[T.MATCH].length == 0;
    }
    
    protected bool is_searching_for_recent ()
    {
      return search_with_empty;
    }
    
    protected bool is_in_initial_status ()
    {
      return (!search_with_empty) && search[T.MATCH].length == 0 && (results[T.MATCH] == null || results[T.MATCH].size == 0);
    }
    
    protected bool can_handle_empty ()
    {
      return handle_empty;
    }
    
    protected string get_match_search () {return search[T.MATCH];}
    protected void set_match_search (string pattern)
    {
      search_with_empty = false;
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
    
    protected void focus_current_match () {focus_match (focus_index[T.MATCH], focus[T.MATCH]);}
    protected void focus_current_action () {focus_action (focus_index[T.ACTION], focus[T.ACTION]);}
    protected Gee.List<Match>? get_action_results () {return results[T.ACTION];}
    protected Gee.List<Match>? get_match_results () {return results[T.MATCH];}
    protected void get_action_focus (out int index, out Match? action) {index = focus_index[T.ACTION]; action = focus[T.ACTION];}
    protected void get_match_focus (out int index, out Match? match) {index = focus_index[T.MATCH]; match = focus[T.MATCH];}

    protected ResultSet last_result_set;
    
    protected void search_for_empty ()
    {
      search_with_empty = true;
      search_for_matches ();
    }
    
    private void search_for_matches ()
    {
      current_cancellable.cancel ();
      current_cancellable = new Cancellable ();

      if (!search_with_empty && search[T.MATCH] == "")
      {
        reset_search (true, false);
        return;
      }
      partial_result_sent = false;

      last_result_set = new ResultSet ();
      if (tid == 0)
      {
        tid = Timeout.add (PARTIAL_TIMEOUT, () => {
            tid = 0;
            _send_partial_results (this.last_result_set);
            return false;
        });
      }
      data_sink.search (search[T.MATCH], qf, last_result_set, current_cancellable, _search_ready);
    }
    
    private void _send_partial_results (ResultSet rs)
    {
      /* Search not ready */
      set_throbber_visible (true);
      partial_result_sent = true;
      /* If partial result set is empty
       * Try to match the new string on current focus
       */
      if (focus[T.MATCH] != null && rs.size == 0)
      {
        var matchers = Query.get_matchers_for_query (search[T.MATCH], 0,
            RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (focus[T.MATCH].title))
          {
            focus_match (focus_index[T.MATCH], focus[T.MATCH]);
            return;
          }
        }
      }
      /* String didn't match, get partial results */
      focus_index[T.MATCH] = 0;
      results[T.MATCH] = rs.get_sorted_list ();
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
      try
      {
        results[T.MATCH] = data_sink.search.end (res);
        /* Do not write code before this line */

        if (!partial_result_sent)
        {
          /* reset current focus */
          focus[T.MATCH] = null;
          focus_index[T.MATCH] = 0;
        }
        /* Search not cancelled and ready */
        set_throbber_visible (false);
        if (tid != 0)
        {
          Source.remove (tid);
          tid = 0;
        }
        if (results[T.MATCH].size > 0)
        {
          if (focus[T.MATCH] != null)
          {
            /* The magic is here, remove che current focus from the new list */
            /* and then reinsert it in the current focus position */
            int i = results[T.MATCH].index_of (focus[T.MATCH]);
            if (i > 0)
            {
              focus_index[T.MATCH] = i;
            }
            else
            {
              // cannot find the item! That's impossible! Btw, select the first item
              focus_index[T.MATCH] = 0;
              focus[T.MATCH] = results[T.MATCH].first ();
            }
          }
          else
          {
            focus[T.MATCH] = results[T.MATCH].get (focus_index[T.MATCH]);
            /* Send also actions */
            search_for_actions ();
          }
        }
        else
        {
          focus[T.MATCH] = null;
          focus_index[T.MATCH] = 0;
          search_for_actions ();
        }

        update_match_result_list (results[T.MATCH], focus_index[T.MATCH], focus[T.MATCH]);
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
      results[T.ACTION] = data_sink.find_actions_for_match (focus[T.MATCH], search[T.ACTION]);
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
      var match = focus[T.MATCH];
      var action = focus[T.ACTION];
      /* Async execute to avoid freezes when executing a dbus action */
      Timeout.add (30, ()=>{ return _execute (match, action);});
      return true;
    }
    private bool _execute (Match match, Match action)
    {
      action.execute (match);
      return false;
    }
    
    private void init_default_command_map ()
    {
      command_map.set (Gdk.KeySyms.Return, CommandTypes.EXECUTE);
      command_map.set (Gdk.KeySyms.KP_Enter, CommandTypes.EXECUTE);
      command_map.set (Gdk.KeySyms.ISO_Enter, CommandTypes.EXECUTE);
      command_map.set (Gdk.KeySyms.Delete, CommandTypes.SEARCH_DELETE_CHAR);
      command_map.set (Gdk.KeySyms.BackSpace, CommandTypes.SEARCH_DELETE_CHAR);
      command_map.set (Gdk.KeySyms.Escape, CommandTypes.CLEAR_SEARCH_OR_HIDE);
      command_map.set (Gdk.KeySyms.Left, CommandTypes.PREV_CATEGORY);
      command_map.set (Gdk.KeySyms.Right, CommandTypes.NEXT_CATEGORY);
      command_map.set (Gdk.KeySyms.Up, CommandTypes.PREV_RESULT);
      command_map.set (Gdk.KeySyms.Down, CommandTypes.NEXT_RESULT);
      command_map.set (Gdk.KeySyms.Home, CommandTypes.FIRST_RESULT);
      command_map.set (Gdk.KeySyms.End, CommandTypes.LAST_RESULT);
      command_map.set (Gdk.KeySyms.Page_Up, CommandTypes.PREV_PAGE);
      command_map.set (Gdk.KeySyms.Page_Down, CommandTypes.NEXT_PAGE);
      command_map.set (Gdk.KeySyms.Tab, CommandTypes.SWITCH_SEARCH_TYPE);
    }
    public void map_key_to_command (uint keyval, CommandTypes command)
    {
      foreach (Gee.Map.Entry<uint, CommandTypes> entry in command_map.entries)
      {
        if (entry.value == command) command_map.unset (entry.key);
      }
      command_map.set (keyval, command);
    }
    public uint get_key_for_command (CommandTypes command)
    {
      foreach (Gee.Map.Entry<uint, CommandTypes> entry in command_map.entries)
      {
        if (entry.value == command) return entry.key;
      }
      return 0;
    }
    protected CommandTypes get_command_from_key_event (Gdk.EventKey event)
    {
      var key = event.keyval;
      if (command_map.has_key (key))
      {
        return command_map.get (key);
      }
      else
        return CommandTypes.INVALID_COMMAND;
    }
  }
}
