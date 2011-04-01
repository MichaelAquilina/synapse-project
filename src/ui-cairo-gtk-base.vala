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
 *
 */

using Gtk;
using Cairo;
using Gee;
using Synapse.Gui.Utils;

namespace Synapse
{
  public class Window : Gtk.Window
  {
    /* --- class for custom gtkrc purpose --- */
    /* In ~/.config/synapse/gtkrc  use:
       widget_class "*SynapseWindow*" style : highest "synapse" 
       and set your custom colors
    */
    construct
    {
      this.set_events (this.get_events () | Gdk.EventMask.BUTTON_PRESS_MASK);
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
    
    public virtual signal void summon ()
    {
      //Synapse.Utils.Logger.log (this, "Summon");
      this.show ();
      Gui.Utils.present_window (this);
    }
    
    public virtual signal void vanish ()
    {
      //Synapse.Utils.Logger.log (this, "Vanish");
      Gui.Utils.unpresent_window (this);
      this.hide ();
    }
    
    public void force_grab ()
    {
      //Synapse.Utils.Logger.log (this, "ForceGrab");
      Gui.Utils.present_window (this);
    }
  }
}

namespace Synapse.Gui
{
  public abstract class GtkCairoBase : UIInterface
  {
    /* With this base ui class, you can create your custom UI by implementing
       only a few methods of ui-interface:
       - protected override void handle_empty_updated ()
       - protected override void focus_match ( int index, Match? match )
       - protected override void focus_action ( int index, Match? action )
       - protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
       - protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
       show () and hide () methods are alredy implemented in this class, but you could always override them.
       
       Your UI should implement following graphical methods:
       - protected override void build_ui ()
         within this method you should build your UI (ie layout).
         There is only one rule: you have to include in your layout following (already implemented here) widgets:
         - flag_selector  (an HTextSelector that handles Query Flags)
         - menu (a MenuButton **this object must be initialized in your class**)
       
       Your UI can override some graphicals methods already handled:
       - protected override void on_composited_changed (Widget w)   //w is window
       - protected virtual void set_input_mask () {}
    */

    protected const int SHADOW_SIZE = 12; // shadow preferred size

    protected Synapse.Window window = null;
    protected MenuButton menu = null;
    protected Throbber throbber = null;
    protected HTextSelector flag_selector = null;
    protected bool searching_for_matches = true;
    protected ColorHelper ch;
    
    protected virtual void set_input_mask () {}
    
    protected IMContext im_context;
    
    construct
    {
      window = new Synapse.Window ();
      window.set_app_paintable (true);
      window.skip_taskbar_hint = true;
      window.skip_pager_hint = true;
      window.set_position (WindowPosition.CENTER);
      window.set_decorated (false);
      window.set_resizable (false);
      window.set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
      window.set_keep_above (true);
      window.window_state_event.connect (on_window_state_event);

      window.vanish.connect (this.hide_and_reset);
      
      ch = new Utils.ColorHelper (window);
      
      /* Query flag selector  */
      flag_selector = new HTextSelector();
      foreach (CategoryConfig.Category c in this.category_config.categories)
      {
        flag_selector.add_text (c.name);
      }
      flag_selector.selected = this.category_config.default_category_index;
      flag_selector.selection_changed.connect (()=>{
        if (!searching_for_matches)
        {
          searching_for_matches = true;
          searching_for_changed ();
        }
        update_query_flags (this.category_config.categories.get (flag_selector.selected).flags);
      });

      /* Build UI */
      build_ui ();
      
      if (menu != null)
      {
        menu.get_menu ().show.connect (window.force_grab);
        menu.settings_clicked.connect (()=>{this.show_settings_clicked ();});
      }

      Utils.ensure_transparent_bg (window);
      on_composited_changed (window);
      window.composited_changed.connect (on_composited_changed);
      window.key_press_event.connect (key_press_event);
      window.delete_event.connect (window.hide_on_delete);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_char);
      im_context.focus_in ();

      focus_match (0, null);
      focus_action (0, null);
      
      if (Synapse.Utils.Logger.debug_enabled ())
      {
        Synapse.Utils.Logger.warning (this, "Debug enabled: Synapse's input grab disabled.");
        // Grab Hack disabled => listen on focus change
        window.notify["is-active"].connect (()=>{
          Idle.add (check_focus);
        });
      }
    }

    ~GtkCairoBase ()
    {
      window.destroy ();
    }
    
    private bool check_focus ()
    {
      if (!window.is_active && (menu == null || !menu.is_menu_visible ()))
      {
        hide ();
      }
      return false;
    }
    
    private bool on_window_state_event (Widget w, Gdk.EventWindowState event)
    {
      /* For whatever reason, keep above is gone.  We don't want that. */
      if ((event.new_window_state & Gdk.WindowState.ABOVE) == 0)
      {
        window.set_keep_above (true);
      }

      return false;
    }

    protected signal void search_string_changed ();
    /* Called when searching_for_matches changes */
    protected signal void searching_for_changed ();
    /* Called when PREV_ or NEXT_ are pressed.
       Return:
       - true if handled or if list has a different status (visible/not visible)
       - false otherwise  */
    protected virtual bool show_list (bool visible) {return false;}
    /* This method MUST build the UI */
    protected abstract void build_ui ();

    protected virtual void on_composited_changed (Widget w)
    {
      Gdk.Screen screen = w.get_screen ();
      bool comp = screen.is_composited ();
      Gdk.Colormap? cm = screen.get_rgba_colormap();
      if (cm == null)
      {
        comp = false;
        cm = screen.get_rgb_colormap();
      }
      Synapse.Utils.Logger.log (this, "Screen is%s composited.", comp ? "": " NOT");
      w.set_colormap (cm);
    }

    protected virtual void search_add_char (string chr)
    {
      if (searching_for_matches)
      {
        set_match_search (get_match_search() + chr);
        set_action_search ("");
      }
      else
        set_action_search (get_action_search() + chr);
      search_string_changed ();
    }
    
    protected virtual void search_delete_char ()
    {
      string s = "";
      if (searching_for_matches)
        s = get_match_search ();
      else
        s = get_action_search ();
      long len = s.length;
      if (len > 0)
      {
        s = Synapse.Utils.remove_last_unichar (s, 0);
        if (searching_for_matches)
        {
          set_match_search (s);
          set_action_search ("");
          if (s == "")
            show_list (false);
        }
        else
          set_action_search (s);
      }
      search_string_changed ();
    }

    protected virtual void hide_and_reset ()
    {
      searching_for_matches = true;
      show_list (false);
      flag_selector.selected = this.category_config.default_category_index;
      reset_search ();
      searching_for_changed ();
      //Synapse.Utils.Logger.log (this, "hide and reset");
    }

    protected virtual void clear_search_or_hide_pressed ()
    {
      if (!searching_for_matches)
      {
        set_action_search ("");
        searching_for_matches = true;
        searching_for_changed ();
        focus_current_match ();
      }
      else if (get_match_search() != "" ||
               get_match_results () != null)
      {
        set_match_search("");
        search_string_changed ();
      }
      else
      {
        window.vanish ();
      }
    }
    
    protected void make_draggable (EventBox obj)
    {
      obj.set_events (obj.get_events () | Gdk.EventMask.BUTTON_PRESS_MASK);
      // D&D
      Gtk.drag_source_set (obj, Gdk.ModifierType.BUTTON1_MASK, {}, 
                               Gdk.DragAction.ASK | 
                               Gdk.DragAction.COPY | 
                               Gdk.DragAction.MOVE | 
                               Gdk.DragAction.LINK);
      obj.button_press_event.connect (this.draggable_clicked);
      obj.drag_data_get.connect (this.draggable_get);
    }
    
    private void draggable_get (Widget w, Gdk.DragContext context, SelectionData selection_data, uint info, uint time_)
    {
      /* Set datas on drop */
      Match m;
      int i;
      this.get_match_focus (out i, out m);

      UriMatch? um = m as UriMatch;
      return_if_fail (um != null);
      selection_data.set_text (um.title, -1);
      selection_data.set_uris ({um.uri});
    }
    
    private bool draggable_clicked (Gtk.Widget w, Gdk.EventButton event)
    {
      var tl = new TargetList ({});
      if (!has_match_results ())
      {
        Gtk.drag_source_set_target_list (w, tl);
        Gtk.drag_source_set_icon_stock (w, Gtk.STOCK_MISSING_IMAGE);
        return false;
      }
      Match m;
      int i;
      this.get_match_focus (out i, out m);

      UriMatch? um = m as UriMatch;
      if (um == null)
      {
        Gtk.drag_source_set_target_list (w, tl);
        Gtk.drag_source_set_icon_stock (w, Gtk.STOCK_MISSING_IMAGE);
        return false;
      }

      tl.add_text_targets (0);
      tl.add_uri_targets (1);
      Gtk.drag_source_set_target_list (w, tl);
      
      try {
        var icon = GLib.Icon.new_for_string (um.icon_name);
        if (icon == null) return false;

        Gtk.IconInfo iconinfo = Gtk.IconTheme.get_default ().lookup_by_gicon (icon, 48, Gtk.IconLookupFlags.FORCE_SIZE);
        if (iconinfo == null) return false;

        Gdk.Pixbuf icon_pixbuf = iconinfo.load_icon ();
        if (icon_pixbuf == null) return false;
        
        Gtk.drag_source_set_icon_pixbuf (w, icon_pixbuf);
      }
      catch (GLib.Error err) {}
      return false;
    }
    
    public void command_execute ()
    {
      if (execute ())
      {
        window.vanish ();
      }
      else
      {
        searching_for_matches = true;
        searching_for_changed ();
      }
    }
    
    protected virtual bool fetch_command (KeyComboConfig.Commands command)
    {
      if (command != command.INVALID_COMMAND)
      {
        switch (command)
        {
          case KeyComboConfig.Commands.EXECUTE_WITHOUT_HIDE:
            execute ();
            searching_for_matches = true;
            searching_for_changed ();
            break;
          case KeyComboConfig.Commands.EXECUTE:
            command_execute ();
            break;
          case KeyComboConfig.Commands.SEARCH_DELETE_CHAR:
            search_delete_char ();
            break;
          case KeyComboConfig.Commands.CLEAR_SEARCH_OR_HIDE:
            clear_search_or_hide_pressed ();
            break;
          case KeyComboConfig.Commands.PREV_CATEGORY:
            flag_selector.select_prev ();
            flag_selector.selection_changed ();
            break;
          case KeyComboConfig.Commands.NEXT_CATEGORY:
            flag_selector.select_next ();
            flag_selector.selection_changed ();
            break;
          case KeyComboConfig.Commands.FIRST_RESULT:
            bool b = true;
            if (searching_for_matches)
              b = select_first_last_match (true);
            else
              b = select_first_last_action (true);
            if (!b) show_list (false);
            break;
          case KeyComboConfig.Commands.LAST_RESULT:
            show_list (true);
            if (searching_for_matches)
              select_first_last_match (false);
            else
              select_first_last_action (false);
            break;
          case KeyComboConfig.Commands.PREV_RESULT:
            bool b = true;
            if (searching_for_matches)
              b = move_selection_match (-1);
            else
              b = move_selection_action (-1);
            if (!b) show_list (false);
            break;
          case KeyComboConfig.Commands.PREV_PAGE:
            bool b = true;
            if (searching_for_matches)
              b = move_selection_match (-5);
            else
              b = move_selection_action (-5);
            if (!b) show_list (false);
            break;
          case KeyComboConfig.Commands.NEXT_RESULT:
            if (can_handle_empty () && is_in_initial_status ())
            {
              show_list (true);
              search_for_empty ();
              return true;
            }
            if (show_list (true)) return true;
            if (searching_for_matches)
              move_selection_match (1);
            else
              move_selection_action (1);
            break;
          case KeyComboConfig.Commands.NEXT_PAGE:
            if (show_list (true)) return true;
            if (searching_for_matches)
              move_selection_match (5);
            else
              move_selection_action (5);
            break;
          case KeyComboConfig.Commands.SWITCH_SEARCH_TYPE:
            if (searching_for_matches && 
                  (
                    get_match_results () == null || get_match_results ().size == 0 ||
                    (get_action_search () == "" && (get_action_results () == null || get_action_results ().size == 0))
                  )
                )
              return true;
            searching_for_matches = !searching_for_matches;
            searching_for_changed ();
            if (searching_for_matches)
            {
              focus_current_match ();
            }
            else
            {
              focus_current_action ();
            }
            break;
          case KeyComboConfig.Commands.ACTIVATE:
            this.hide ();
            break;
          case KeyComboConfig.Commands.PASTE:
            var display = window.get_display ();
            var clipboard = Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            // Get text from clipboard
            string text = clipboard.wait_for_text ();
            if (searching_for_matches)
              set_match_search (get_match_search () + text);
            else
              set_action_search (get_action_search () + text);
            search_string_changed ();
            break;
          default:
            //debug ("im_context didn't filter...");
            break;
        }
        return true;
      }
      return false;
    }
    
    protected virtual bool key_press_event (Gdk.EventKey event)
    {
      /* Check for commands */
      KeyComboConfig.Commands command = 
        this.key_combo_config.get_command_from_eventkey (event);
      
      if (this.fetch_command (command)) return true;
      /* Check for text input */
      im_context.filter_keypress (event);
      return true;
    }

    /* UI INTERFACE IMPLEMENTATION */
    public override void show ()
    {
      if (window.visible) return;
      show_list (true);
      Utils.move_window_to_center (window);
      show_list (false);
      window.summon ();
      set_input_mask ();
    }
    public override void hide ()
    {
      window.vanish ();
    }
    public override void show_hide_with_time (uint32 timestamp)
    {
      if (window.visible)
      {
        hide ();
        return;
      }
      show ();
    }    
    protected override void set_throbber_visible (bool visible)
    {
      if (throbber == null) return;
      if (visible)
        throbber.active = true;
      else
        throbber.active = false;
    }
  }
}
