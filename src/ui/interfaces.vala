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
  
  public interface IModel : Object
  {
    /* Search strings */
    public abstract string[] query
      { get; } //cardinality : SearchingFor.COUNT
    
    /* Result Sets */
    public abstract Gee.List<Match>[] results
      { get; } //cardinality : SearchingFor.COUNT

    /* Focus */
    public abstract Entry<int, Match>[] focus
      { get; } //cardinality : SearchingFor.COUNT
      
    /* Multiple Selection :: maybe in the future */
    //public abstract Gee.Map<int, Match> selected_sources {get; set;}
    //public abstract Gee.Map<int, Match> selected_targets {get; set;}
    
    /* Category */
    public abstract int selected_category {get; set;}
    
    /* SearchingFor */
    public abstract SearchingFor searching_for {get; set;}
    
    /* returns results[searching_for] != null && .size > 0 */
    public abstract bool has_results ();
    
    public abstract Entry<int, Match> get_actual_focus ();
    
    public abstract void set_actual_focus (int i);
    
    public abstract void clear (int default_category = 0);
    public abstract void clear_searching_for (SearchingFor what);
  }
  
  public interface IController : Object
  {
    /* Construct properties */
    public abstract DataSink data_sink { get; construct set; }
    public abstract KeyComboConfig key_combo_config { get; construct set; }
    public abstract CategoryConfig category_config { get; construct set; }
    
    public static const int RESULTS_PER_PAGE = 5;
    public static const int PARTIAL_RESULT_TIMEOUT = 110;
    
    /* Events called by View */
    
    /* key_press_event should be fired on key press */
    public abstract void key_press_event (Gdk.EventKey event);
    
    /* category_changed_event should be fired ie when user clicks on a category */
    public abstract void category_changed_event (int category_index);
    
    /* selected_index_changed should be fired when users clicks on an item in the list */
    /* Model.focus[Model.searching_for] will be changed */
    public abstract void selected_index_changed_event (int focus_index);
    
    /* Events called by Synapse-Main */
    public abstract void set_view (Type view_type);

    /* Shows or hide the View */
    public abstract void summon_or_vanish ();
  }
  
  public interface IView : Object
  {
    public signal void summoned ();
    public signal void vanished ();
    public abstract void summon ();
    public abstract void vanish ();
    public abstract void summon_or_vanish ();
    
    public abstract Synapse.Gui.IModel model {get; construct set;}
    public abstract Synapse.Gui.IController controller {get; construct set;}
    
    public abstract void update_focused_source ();
    public abstract void update_focused_action ();
    public abstract void update_focused_target ();
    
    public abstract void update_sources ();
    public abstract void update_actions ();
    public abstract void update_targets ();
    
    public abstract void update_selected_category ();
    
    public abstract void update_searching_for ();
    
    public abstract bool is_list_visible ();
    public abstract void set_list_visible (bool visible);
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
