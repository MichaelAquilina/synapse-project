/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
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
  public enum SearchingFor
  {
    SOURCES,
    ACTIONS,
    TARGETS,
    
    COUNT
  }

  public interface IController : Object
  {
    /* Helpful strings */
    public static string SEARCHING; /* Searching... */
    public static string NO_RESULTS; /* No results found. */
    public static string NO_RECENT_ACTIVITIES; /* No recent activities found. */
    public static string TYPE_TO_SEARCH; /* Type to search */
    public static string DOWN_TO_SEE_RECENT; /* Press down to see recent */
    
    /* Construct properties */
    public abstract DataSink data_sink { get; construct set; }
    public abstract KeyComboConfig key_combo_config { get; construct set; }
    public abstract CategoryConfig category_config { get; construct set; }
    
    public static const int RESULTS_PER_PAGE = 5;
    public static const int PARTIAL_RESULT_TIMEOUT = 120;
    
    /* Events called by View */
    
    /* key_press_event should be fired on key press */
    public abstract void key_press_event (Gdk.EventKey event);
    
    /* category_changed_event should be fired ie when user clicks on a category */
    public abstract void category_changed_event (int category_index);
    
    /* fire_focus should be fired ie when user dblclicks on a item in the list */
    public abstract void fire_focus ();
    
    /* selected_index_changed should be fired when users clicks on an item in the list */
    /* Model.focus[Model.searching_for] will be changed */
    public abstract void selected_index_changed_event (int focus_index);
    
    /* Events called by Synapse-Main */
    public abstract void set_view (Type view_type);

    /* Shows or hide the View */
    public abstract void summon_or_vanish ();
    
    /* Tells if the controller is in initial state (no search active) */
    public abstract bool is_in_initial_state ();
    
    /* Tells if the controller searched for recent activities in current searching for */
    public abstract bool searched_for_recent ();
    
    /* Tells at synapse main, that the user wants to configure synapse */
    public signal void show_settings_requested ();
    
    /* Tells to views that now it can/cant search for recent activities */
    public signal void handle_recent_activities (bool can);
  }
  
  public interface IView : Object
  {
    public signal void summoned ();
    public signal void vanished ();
    public abstract void summon ();
    public abstract void vanish ();
    public abstract void summon_or_vanish ();
    
    public abstract Synapse.Gui.Model controller_model {get; construct set;}
    public abstract Synapse.Gui.IController controller {get; construct set;}
    
    public abstract void update_focused_source (Entry<int, Match> m);
    public abstract void update_focused_action (Entry<int, Match> m);
    public abstract void update_focused_target (Entry<int, Match> m);
    
    public abstract void update_sources (Gee.List<Match>? list = null);
    public abstract void update_actions (Gee.List<Match>? list = null);
    public abstract void update_targets (Gee.List<Match>? list = null);
    
    public abstract void update_selected_category ();
    
    public abstract void update_searching_for ();
    
    public abstract bool is_list_visible ();
    public abstract void set_list_visible (bool visible);
    public abstract void set_throbber_visible (bool visible);
  }
  
  public class Entry<K, V>
  {
    public K? key {
      get; set;
    }
    public V? value {
      get; set;
    }
    
    public Entry ()
    {
      
    }
    
    public Entry.kv (K? key, V? value)
    {
      this.key = key;
      this.value = value;
    }
  }
}
