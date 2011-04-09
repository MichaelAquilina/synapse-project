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
  }
  
  public interface IController : Object
  {
    /* Construct properties */
    public abstract DataSink data_sink { get; construct set; }
    public abstract KeyComboConfig key_combo_config { get; construct set; }
    public abstract CategoryConfig category_config { get; construct set; }
    
    public static const int RESULTS_PER_PAGE = 5;
    
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

namespace Synapse
{
  public class View : Gtk.Window, Synapse.Gui.IView
  {
    /* --- class for custom gtkrc purpose --- */
    /* In ~/.config/synapse/gtkrc  use:
       widget_class "*SynapseWindow*" style : highest "synapse" 
       and set your custom colors
    */
    protected bool is_kwin = false;
    
    private void update_wm ()
    {
      string wmname = Gdk.x11_screen_get_window_manager_name (Gdk.Screen.get_default ()).down ();
      this.is_kwin = wmname == "kwin";
    }
    
    construct
    {
      update_wm ();
      if (is_kwin) Synapse.Utils.Logger.log (this, "Using KWin compatibiliy mode.");
      
      this.set_app_paintable (true);
      this.skip_taskbar_hint = true;
      this.skip_pager_hint = true;
      this.set_position (Gtk.WindowPosition.CENTER);
      this.set_decorated (false);
      this.set_resizable (false);
      /* SPLASHSCREEN is needed for Metacity/Compiz, but doesn't work with KWin */
      if (is_kwin)
        this.set_type_hint (Gdk.WindowTypeHint.NORMAL);
      else
        this.set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
      this.set_keep_above (true);

      /* Listen on click events */
      this.set_events (this.get_events () | Gdk.EventMask.BUTTON_PRESS_MASK
                                          | Gdk.EventMask.KEY_PRESS_MASK);
    }
    
    public override bool button_press_event (Gdk.EventButton event)
    {
      int x = (int)event.x_root;
      int y = (int)event.y_root;
      int rx, ry;
      this.get_window ().get_root_origin (out rx, out ry);

      if (!Gui.Utils.is_point_in_mask (this, x - rx, y - ry)) this.vanish ();

      return false;
    }
    
    public override bool key_press_event (Gdk.EventKey event)
    {
      this.controller.key_press_event (event);
      return false;
    }

    public void force_grab ()
    {
      Gui.Utils.present_window (this);
    }
    
    public virtual void summon ()
    {
      this.show ();
      Gui.Utils.present_window (this);
      this.summoned ();
    }

    public virtual void vanish ()
    {
      Gui.Utils.unpresent_window (this);
      this.hide ();
      this.vanished ();
    }

    public virtual void summon_or_vanish ()
    {
      if (this.visible)
        vanish ();
      else
        summon ();
    }
    
    public Synapse.Gui.IModel model {get; construct set;}
    public Synapse.Gui.IController controller {get; construct set;}
    
    public virtual void update_focused_source (){}
    public virtual void update_focused_action (){}
    public virtual void update_focused_target (){}

    public virtual void update_sources (){}
    public virtual void update_actions (){}
    public virtual void update_targets (){}
    
    public virtual void update_selected_category (){}
    
    public virtual void update_searching_for (){}
    
    public virtual bool is_list_visible (){ return true; }
    public virtual void set_list_visible (bool visible){}
  }
}
