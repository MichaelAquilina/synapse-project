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
    protected string[] categories =
    {
      _("Actions"),
      _("Audio"),
      _("Applications"),
      _("All"),
      _("Documents"),
      _("Images"),
      _("Video"),
      _("Internet")
    };
    protected QueryFlags[] categories_query =
    {
      QueryFlags.ACTIONS,
      QueryFlags.AUDIO,
      QueryFlags.APPLICATIONS,
      QueryFlags.ALL,
      QueryFlags.DOCUMENTS,
      QueryFlags.IMAGES,
      QueryFlags.VIDEO,
      QueryFlags.INTERNET | QueryFlags.INCLUDE_REMOTE
    };
    
    protected const int SHADOW_SIZE = 12; // shadow preferred size

    protected Window window = null;
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
      window.skip_taskbar_hint = true;
      window.skip_pager_hint = true;
      window.set_position (WindowPosition.CENTER);
      window.set_decorated (false);
      window.set_resizable (false);
      window.set_type_hint (Gdk.WindowTypeHint.DIALOG);
      window.set_keep_above (true);
      window.window_state_event.connect (on_window_state_event);
      window.notify["is-active"].connect (()=>{
        Idle.add (check_focus);
      });
      
      ch = new Utils.ColorHelper (window);
      
      /* Query flag selector  */
      flag_selector = new HTextSelector();
      foreach (string s in this.categories)
      {
        flag_selector.add_text (s);
      }
      flag_selector.selected = 3;

      /* Build UI */
      build_ui ();

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
    }

    ~GtkCairoBase ()
    {
      window.destroy ();
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
    
    private bool check_focus ()
    {
      if (!window.is_active && (menu == null || !menu.is_menu_visible ()))
      {
        hide ();
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
      window.hide ();
      searching_for_matches = true;
      show_list (false);
      flag_selector.selected = 3;
      reset_search ();
      searching_for_changed ();
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
        hide ();
      }
    }
    
    protected virtual bool key_press_event (Gdk.EventKey event)
    {
      /* Check for text input */
      if (im_context.filter_keypress (event)) return true;

      /* Check for Paste command Ctrl+V */
      if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && 
          (Gdk.keyval_to_lower (event.keyval) == (uint)'v'))
      {
        var display = window.get_display ();
        var clipboard = Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
        // Get text from clipboard
        string text = clipboard.wait_for_text ();
        if (searching_for_matches)
          set_match_search (get_match_search () + text);
        else
          set_action_search (get_action_search () + text);
        search_string_changed ();
        return true;
      }

      /* Check for commands */
      CommandTypes command = get_command_from_key_event (event);

      switch (command)
      {
        case CommandTypes.EXECUTE_WITHOUT_HIDE:
          execute ();
          searching_for_matches = true;
          searching_for_changed ();
          break;
        case CommandTypes.EXECUTE:
          if (execute ())
            hide ();
          else
          {
            searching_for_matches = true;
            searching_for_changed ();
          }
          break;
        case CommandTypes.SEARCH_DELETE_CHAR:
          search_delete_char ();
          break;
        case CommandTypes.CLEAR_SEARCH_OR_HIDE:
          clear_search_or_hide_pressed ();
          break;
        case CommandTypes.PREV_CATEGORY:
          flag_selector.select_prev ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            searching_for_changed ();
          }
          update_query_flags (this.categories_query[flag_selector.selected]);
          break;
        case CommandTypes.NEXT_CATEGORY:
          flag_selector.select_next ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            searching_for_changed ();
          }
          update_query_flags (this.categories_query[flag_selector.selected]);
          break;
        case CommandTypes.FIRST_RESULT:
          bool b = true;
          if (searching_for_matches)
            b = select_first_last_match (true);
          else
            b = select_first_last_action (true);
          if (!b) show_list (false);
          break;
        case CommandTypes.LAST_RESULT:
          show_list (true);
          if (searching_for_matches)
            select_first_last_match (false);
          else
            select_first_last_action (false);
          break;
        case CommandTypes.PREV_RESULT:
          bool b = true;
          if (searching_for_matches)
            b = move_selection_match (-1);
          else
            b = move_selection_action (-1);
          if (!b) show_list (false);
          break;
        case CommandTypes.PREV_PAGE:
          bool b = true;
          if (searching_for_matches)
            b = move_selection_match (-5);
          else
            b = move_selection_action (-5);
          if (!b) show_list (false);
          break;
        case CommandTypes.NEXT_RESULT:
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
        case CommandTypes.NEXT_PAGE:
          if (show_list (true)) return true;
          if (searching_for_matches)
            move_selection_match (5);
          else
            move_selection_action (5);
          break;
        case CommandTypes.SWITCH_SEARCH_TYPE:
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
        default:
          //debug ("im_context didn't filter...");
          break;
      }

      return true;
    }

    /* UI INTERFACE IMPLEMENTATION */
    public override void show ()
    {
      if (window.visible) return;
      show_list (true);
      Utils.move_window_to_center (window);
      show_list (false);
      window.show ();
      set_input_mask ();
    }
    public override void hide ()
    {
      hide_and_reset ();
    }
    public override void show_hide_with_time (uint32 timestamp)
    {
      if (window.visible)
      {
        hide ();
        return;
      }
      show ();
      window.present_with_time (timestamp);
      window.get_window ().raise ();
      window.get_window ().focus (timestamp);
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
