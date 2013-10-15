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
  public class Controller : IController, Object
  {
    static construct
    {
      SEARCHING = _("Searching...");
      NO_RESULTS = _("No results found.");
      NO_RECENT_ACTIVITIES = _("No recent activities found.");
      TYPE_TO_SEARCH = _("Type to search...");
      DOWN_TO_SEE_RECENT = "";
    }

    /* Construct properties */
    public DataSink data_sink { get; construct set; }
    public KeyComboConfig key_combo_config { get; construct set; }
    public CategoryConfig category_config { get; construct set; }
    
    protected Model model;
    protected IView view = null;

    public void set_view (Type view_type)
    {
      if (!view_type.is_a (typeof (IView))) return;
      if (this.view != null) this.view.vanish ();
      IconCacheService.get_default ().clear_cache ();
      this.view = GLib.Object.new (view_type, "controller-model", this.model,
                                              "controller", this) as IView;
      reset_search (true, true);

      // Input Method Fix
      if (this.view is Gtk.Window) //this has to be true, otherwise im_context will not work well
      {
        Gtk.Window v = this.view as Gtk.Window;

        Synapse.Utils.Logger.log (view, "Using %s input method.", im_context.get_context_id ());

        v.focus_in_event.connect ( ()=> {
          im_context.reset ();
          im_context.focus_in ();
          return false;
        });

        v.focus_out_event.connect ( ()=>{
          im_context.focus_out ();
          return false;
        });
      }
      this.view.vanished.connect (()=>{
        reset_search (true, true);
      });
    }
    
    /* Events called by View */
    
    /* key_press_event should be fired on key press */
    public void key_press_event (Gdk.EventKey event)
    {
      bool filtered = false;
      /* Check for text input */
      filtered = im_context.filter_keypress (event);

      if (filtered && (event.state & KeyComboConfig.mod_normalize_mask) == 0) return;

      /* Check for commands */
      KeyComboConfig.Commands command = 
        this.key_combo_config.get_command_from_eventkey (event);
      
      if (command != KeyComboConfig.Commands.INVALID_COMMAND)
      {
        im_context.reset ();
        this.fetch_command (command);
      }
    }
    
    /* category_changed_event should be fired ie when user clicks on a category */
    public void category_changed_event (int category_index)
    {
      if (category_index < 0 || category_index >= category_config.categories.size)
      {
        /* WTF! Invalid index, update view with the right category. */
        view.update_selected_category ();
        return;
      }

      if (category_index == model.selected_category) return;

      model.selected_category = category_index;
      model.searching_for = SearchingFor.SOURCES;

      view.update_selected_category ();
      view.update_searching_for ();
      
      qf = this.category_config.categories.get (category_index).flags;
      
      if (model.query[SearchingFor.SOURCES] != "" || this.search_recent_activities)
        search_for_matches (SearchingFor.SOURCES, this.search_recent_activities);
    }
    
    public void fire_focus ()
    {
      this.execute (true);
    }

    
    /* selected_index_changed should be fired when users clicks on an item in the list */
    /* Model.focus[Model.searching_for] will be changed */
    public void selected_index_changed_event (int focus_index)
    {
      if (!model.has_results ()) return;
      if (focus_index < 0) focus_index = 0;
      if (focus_index >= model.results[model.searching_for].size)
        focus_index = model.results[model.searching_for].size - 1;

      if (focus_index == model.focus[model.searching_for].key) return;

      model.set_actual_focus (focus_index);
      switch (model.searching_for)
      {
        case SearchingFor.SOURCES:
          model.clear_searching_for (SearchingFor.ACTIONS);
          search_for_actions ();
          
          view.update_focused_source (model.focus[model.searching_for]);
          break;
        case SearchingFor.ACTIONS:
          if (model.results[SearchingFor.TARGETS] != null)
          {
            model.clear_searching_for (SearchingFor.TARGETS);
            view.update_targets (null);
            view.update_focused_target (model.focus[SearchingFor.TARGETS]);
          }
          if (model.focus[SearchingFor.ACTIONS].value.needs_target())
            search_for_matches (SearchingFor.TARGETS, true);

          view.update_focused_action (model.focus[model.searching_for]);
          break;
        default: //case SearchingFor.TARGETS:
          view.update_focused_target (model.focus[model.searching_for]);
          break;
      }
    }
    
    /* Events called by Synapse-Main */
    
    /* Shows or hide the View */
    public void summon_or_vanish ()
    {
      if (this.view == null) return;
      this.view.summon_or_vanish ();
    }
    
    /* End interface implementation */
    protected Gtk.IMMulticontext im_context;
    
    construct 
    {
      /* Initialize model */
      this.model = new Model ();
      this.init_search ();

      /* Typing handle */
      im_context = new Gtk.IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_delete_char);
    }
    
    protected void execute (bool hide = true)
    {
      if (this.model.focus[SearchingFor.SOURCES].value == null) return;
      if (this.model.focus[SearchingFor.ACTIONS].value == null) return;

      var source = this.model.focus[SearchingFor.SOURCES].value;
      var action = this.model.focus[SearchingFor.ACTIONS].value;
      var target = this.model.focus[SearchingFor.TARGETS].value;
      
      if (action is SearchMatch)
      {
        var sm = action as SearchMatch;
        sm.search_source = source;

        model.searching_for = SearchingFor.SOURCES;
        view.update_searching_for ();
        search_for_matches (SearchingFor.SOURCES, true, sm);
        model.clear_searching_for (SearchingFor.SOURCES, false);
        view.update_sources (null);
        return;
      }

      if ( (action.needs_target () && target == null) ||
           (!action.needs_target () && target != null)
         ) return; // can't do that
      
      Timeout.add (20, ()=>{
        action.execute_with_target (source, target);
        return false;
      });

      if (hide)
      {
        this.view.vanish ();
        this.view.set_list_visible (false);
        this.reset_search (true, true);
      }
      else
      {
        // TODO: and now?!
      }
    }
    
    protected void search_add_delete_char (string? newchar = null)
    {
      if (newchar == null)
      {
        // delete
        if (model.query[model.searching_for] == "") return;
        model.query[model.searching_for] = 
          Synapse.Utils.remove_last_unichar (model.query[model.searching_for]);
      }
      else
      {
        // add
        model.query[model.searching_for] = 
              model.query[model.searching_for] + newchar;
      }
      switch (model.searching_for)
      {
        case SearchingFor.SOURCES:
          search_for_matches (SearchingFor.SOURCES);
          this.search_recent_activities = false;
          break;
        case SearchingFor.ACTIONS:
          search_for_actions ();
          break;
        default: //case SearchingFor.TARGETS:
          search_for_matches (SearchingFor.TARGETS, true);
          break;
      }
    }
    
    protected virtual void clear_search_or_hide_pressed ()
    {
      if (model.searching_for != SearchingFor.SOURCES)
      {
        model.query[SearchingFor.ACTIONS] = "";
        model.searching_for = SearchingFor.SOURCES;
        search_for_actions ();
        view.update_searching_for ();
      }
      else if (model.query[SearchingFor.SOURCES] != "" ||
               this.search_recent_activities)
      {
        reset_search (true, false);
        view.set_list_visible (false);
      }
      else
      {
        view.vanish ();
        reset_search (true, true);
        view.set_list_visible (false);
      }
    }
    
    protected virtual bool fetch_command (KeyComboConfig.Commands command)
    {
      if (command != KeyComboConfig.Commands.INVALID_COMMAND)
      {
        switch (command)
        {
          case KeyComboConfig.Commands.EXECUTE_WITHOUT_HIDE:
            execute (false);
            break;
          case KeyComboConfig.Commands.EXECUTE:
            execute (true);
            break;
          case KeyComboConfig.Commands.SEARCH_DELETE_CHAR:
            search_add_delete_char ();
            break;
          case KeyComboConfig.Commands.CLEAR_SEARCH_OR_HIDE:
            clear_search_or_hide_pressed ();
            break;
          case KeyComboConfig.Commands.PREV_CATEGORY:
            if (model.searching_for == SearchingFor.TARGETS) break;
            category_changed_event (model.selected_category - 1);
            break;
          case KeyComboConfig.Commands.NEXT_CATEGORY:
            if (model.searching_for == SearchingFor.TARGETS) break;
            category_changed_event (model.selected_category + 1);
            break;
          case KeyComboConfig.Commands.FIRST_RESULT:
            if (view.is_list_visible () && this.model.focus[this.model.searching_for].key == 0)
            {
              view.set_list_visible (false);
              break;
            }
            selected_index_changed_event (0);
            break;
          case KeyComboConfig.Commands.LAST_RESULT:
            if (!view.is_list_visible ())
            {
              view.set_list_visible (true);
            }
            if (model.has_results ())
              selected_index_changed_event (this.model.results[this.model.searching_for].size - 1);
            break;
          case KeyComboConfig.Commands.PREV_RESULT:
            if (view.is_list_visible () && this.model.focus[this.model.searching_for].key == 0)
            {
              view.set_list_visible (false);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key - 1);
            break;
          case KeyComboConfig.Commands.PREV_PAGE:
            if (view.is_list_visible () && this.model.focus[this.model.searching_for].key == 0)
            {
              view.set_list_visible (false);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key - RESULTS_PER_PAGE);
            break;
          case KeyComboConfig.Commands.NEXT_RESULT:
            if (this.is_in_initial_state () && handle_empty)
            {
              this.search_recent_activities = true;
              this.search_for_matches (SearchingFor.SOURCES, true);
              view.set_list_visible (true);
              break;
            }
            if (!view.is_list_visible ())
            {
              view.set_list_visible (true);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key + 1);
            break;
          case KeyComboConfig.Commands.NEXT_PAGE:
            if (!view.is_list_visible ())
            {
              view.set_list_visible (true);
              break;
            }
            selected_index_changed_event (this.model.focus[this.model.searching_for].key + RESULTS_PER_PAGE);
            break;
          case KeyComboConfig.Commands.NEXT_PANE:
            switch (this.model.searching_for)
            {
              case SearchingFor.SOURCES:
                if (this.model.focus[SearchingFor.SOURCES].value != null)
                {
                  this.model.searching_for = SearchingFor.ACTIONS;
                  view.update_searching_for ();
                }
                break;
              case SearchingFor.ACTIONS:
                if (this.model.focus[SearchingFor.ACTIONS].value != null &&
                    this.model.focus[SearchingFor.ACTIONS].value.needs_target ())
                {
                  this.model.searching_for = SearchingFor.TARGETS;
                }
                else
                {
                  this.model.searching_for = SearchingFor.SOURCES;
                }
                view.update_searching_for ();
                break;
              default: //TARGETS
                this.model.searching_for = SearchingFor.ACTIONS; //go back to actions
                view.update_searching_for ();
                break;
            }
            break;
          case KeyComboConfig.Commands.PREV_PANE:
            switch (this.model.searching_for)
            {
              case SearchingFor.ACTIONS:
                this.model.searching_for = SearchingFor.SOURCES; //go back to sources
                view.update_searching_for ();
                break;
              case SearchingFor.TARGETS:
                this.model.searching_for = SearchingFor.ACTIONS; //go back to actions
                view.update_searching_for ();
                break;
              default: //SOURCES
                //cannot go back from sources
                break;
            }
            break;
          case KeyComboConfig.Commands.ACTIVATE:
            view.vanish ();
            reset_search (true, true);
            view.set_list_visible (false);
            break;
          case KeyComboConfig.Commands.EXIT_SYNAPSE:
            Gtk.main_quit ();
            break;
          case KeyComboConfig.Commands.PASTE:
            Gdk.Display? display = null;
            if (view is Gtk.Widget)
            {
              display = (view as Gtk.Widget).get_display ();
            }
            if (display == null)
            {
              display = Gdk.Screen.get_default ().get_display ();
            }
            var clipboard = Gtk.Clipboard.get_for_display (display, 
              Gdk.SELECTION_CLIPBOARD);
            // Get text from clipboard
            string text = clipboard.wait_for_text ();
            if (text != null && text != "")
            {
              search_add_delete_char (text);
            }
            break;
          case KeyComboConfig.Commands.PASTE_SELECTION:
            Gdk.Display? display = null;
            if (view is Gtk.Widget)
            {
              display = (view as Gtk.Widget).get_display ();
            }
            if (display == null)
            {
              display = Gdk.Screen.get_default ().get_display ();
            }
            var clipboard = Gtk.Clipboard.get_for_display (display, 
              Gdk.SELECTION_PRIMARY);
            // Get text from clipboard
            string text = clipboard.wait_for_text ();
            if (text != null && text != "")
            {
              search_add_delete_char (text);
            }
            break;
        }
        return true;
      }
      return false;
    }
    
    /* Tells if the controller is in initial state (no search active) */
    public bool is_in_initial_state ()
    {
      return model.query[SearchingFor.SOURCES] == "" &&
             model.focus[SearchingFor.SOURCES].value == null &&
             (!search_recent_activities);
    }
    
    /* Tells if the controller is searching for recent activities in current searching for */
    public bool searched_for_recent ()
    {
      if (searching[model.searching_for]) return false; //search in progress..
      switch (model.searching_for)
      {
        case SearchingFor.SOURCES: return search_recent_activities;
        case SearchingFor.ACTIONS: return false;
        default: return model.query[SearchingFor.TARGETS] == "";
      }
    }
    
    /* ------------ Search Engine here ---------------- */
    private bool search_recent_activities = false;
    private bool handle_empty = false;
    private QueryFlags qf;
    /* Stupid Vala: I can't use array[SearchingFor.COUNT] for declaration */
    private Cancellable current_cancellable[3];
    private uint tid[3];
    private bool partial_result_sent[3];
    private bool searching[3];
    
    private ResultSet last_result_set; //FIXME: is this really needed here?!
    
    private void init_search ()
    {
      for (int i = 0; i < SearchingFor.COUNT; i++)
      {
        current_cancellable[i] = new Cancellable ();
        tid[i] = 0;
        partial_result_sent[i] = false;
        searching[i] = false;
      }
      model.clear (category_config.default_category_index);

      qf = category_config.categories.get (category_config.default_category_index).flags;
      last_result_set = null;
      
      data_sink.notify["has-empty-handlers"].connect (update_handle_empty);
      update_handle_empty ();
    }
    
    private void update_handle_empty ()
    {
      handle_empty = data_sink.has_empty_handlers;
      DOWN_TO_SEE_RECENT = handle_empty ? _("...or press down key to browse recent activities") : "";
      if (view != null) view.update_focused_source (model.focus[SearchingFor.SOURCES]);
      handle_recent_activities (handle_empty);
    }
    
    /**
     * This method can be called to reset the search.
     * @param notify if true, visual update matches and actions in the UI
     * @param reset_flags, if true, resets query flags to default (All)
     */
    protected void reset_search (bool notify = true, bool reset_flags = true)
    {
      // Synapse.Utils.Logger.log (this, "RESET");
      for (int i = 0; i < SearchingFor.COUNT; i++)
      {
        current_cancellable[i].cancel ();
        current_cancellable[i] = new Cancellable ();
        if (tid[i] != 0)
        {
          Source.remove (tid[i]);
          tid[i] = 0;
        }
        partial_result_sent[i] = false;
        searching[i] = false;
      }
      search_recent_activities = false;
      model.clear ();
      if (reset_flags)
      {
        model.selected_category = this.category_config.default_category_index;
        qf = this.category_config.categories.get (model.selected_category).flags;
        if (view == null) return;
        view.update_selected_category ();
      }
      if (notify && view != null)
      {
        view.set_throbber_visible (false);
        view.update_sources ();
        view.update_actions ();
        view.update_targets ();
        view.update_focused_source (model.focus[SearchingFor.SOURCES]);
        view.update_focused_action (model.focus[SearchingFor.ACTIONS]);
        view.update_focused_target (model.focus[SearchingFor.TARGETS]);
        view.update_searching_for ();
      }
    }
    
    private void search_for_matches (SearchingFor what, bool search_with_empty = false, SearchProvider? search_provider = null)
    {
      // Synapse.Utils.Logger.log (this, "search_for_matches: %u", what);
    
      current_cancellable[what].cancel ();
      current_cancellable[what] = new Cancellable ();
      
      if (search_provider == null) search_provider = data_sink;
      
      if (what == SearchingFor.SOURCES)
      {
        /* Stop search on targets, just in case */
        current_cancellable[SearchingFor.TARGETS].cancel ();
        current_cancellable[SearchingFor.TARGETS] = new Cancellable ();
        partial_result_sent[SearchingFor.TARGETS] = false;
        if (tid[SearchingFor.TARGETS] != 0)
        {
          Source.remove (tid[SearchingFor.TARGETS]);
          tid[SearchingFor.TARGETS] = 0;
        }
      }
      else
      {
        /* You cannot search for targets if you don't have an action */
        return_if_fail (model.focus[SearchingFor.ACTIONS].value != null);
      }

      /* if string is empty, and not want to search recent activities, reset */
      if (what == SearchingFor.SOURCES && !search_with_empty && model.query[what]=="")
      {
        reset_search (true, false);
        return;
      }
      
      partial_result_sent[what] = false;

      last_result_set = new ResultSet ();
      if (tid[what] == 0)
      {
        tid[what] = Timeout.add (PARTIAL_RESULT_TIMEOUT, () => {
            tid[what] = 0;
            send_partial_results (what, this.last_result_set);
            return false;
        });
      }
      
      searching[what] = true;
      
      search_provider.search.begin (model.query[what],
                              what == SearchingFor.SOURCES ? qf : model.focus[SearchingFor.ACTIONS].value.target_flags (),
                              last_result_set,
                              current_cancellable[what],
                              (obj, res)=>{
        try 
        {
          var rs = (obj as SearchProvider).search.end (res);
          search_ready (what, rs);
        }
        catch (Error e) {
          //cancelled
        }
      });
    }
    
    private void send_partial_results (SearchingFor what, ResultSet rs)
    {
      // Synapse.Utils.Logger.log (this, "partial_matches: %u", what);
      /* Search not ready */
      view.set_throbber_visible (true);
      partial_result_sent[what] = true;
      /* If partial result set is empty
       * Try to match the new string on current focus
       */
      if (model.focus[what].value != null && rs.size == 0)
      {
        var matchers = Query.get_matchers_for_query (model.query[what], 0,
            RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (model.focus[what].value.title))
          {
            if (what == SearchingFor.SOURCES)
              view.update_focused_source (model.focus[what]);
            else
              view.update_focused_target (model.focus[what]);
            return;
          }
        }
      }
      /* String didn't match, get partial results */
      model.focus[what].key = 0;
      model.results[what] = rs.get_sorted_list ();
      if (model.results[what].size > 0)
      {
        model.focus[what].value = model.results[what].first();
      }
      else
      {
        model.focus[what].value = null;
      }
      
      if (what == SearchingFor.SOURCES)
      {
        /* It's important to search for actions before show the match */
        model.clear_searching_for (SearchingFor.ACTIONS);
        search_for_actions ();
        
        view.update_sources (model.results[what]);
        view.update_focused_source (model.focus[what]);
      }
      else
      {
        view.update_targets (model.results[what]);
        view.update_focused_target (model.focus[what]);
      }
    }
    
    private void search_ready (SearchingFor what, Gee.List<Match> res)
    {
      // Synapse.Utils.Logger.log (this, "ready_for_matches: %u", what);
      if (!partial_result_sent[what])
      {
        /* reset current focus */
        model.focus[what].value = null;
        model.focus[what].key = 0;
      }
      model.results[what] = res;

      /* Search not cancelled and ready */
      if (tid[what] != 0)
      {
        Source.remove (tid[what]);
        tid[what] = 0;
      }
      
      searching[what] = false;
      
      if (tid[SearchingFor.SOURCES] == 0 && tid[SearchingFor.TARGETS] == 0)
      {
        view.set_throbber_visible (false);
      }
      
      if (model.results[what].size > 0)
      {
        if (model.focus[what].value != null)
        {
          /* The magic is here, remove che current focus from the new list */
          /* and then reinsert it in the current focus position */
          int i = model.results[what].index_of (model.focus[what].value);
          if (i >= 0)
          {
            model.focus[what].key = i;
          }
          else
          {
            // cannot find the item! That's impossible! Btw, select the first item
            model.focus[what].key = 0;
            model.focus[what].value = model.results[what].first();
          }
        }
        else
        {
          model.focus[what].value = model.results[what].get (model.focus[what].key);
        }
      }
      else
      {
        model.focus[what].value = null;
        model.focus[what].key = 0;
        model.results[what] = null;
      }

      if (what == SearchingFor.SOURCES)
      {
        /* It's important to search for actions before show the match */
        model.clear_searching_for (SearchingFor.ACTIONS);
        search_for_actions ();
        
        view.update_sources (model.results[what]);
        view.update_focused_source (model.focus[what]);
      }
      else
      {
        view.update_targets (model.results[what]);
        view.update_focused_target (model.focus[what]);
      }
    }

    private void search_for_actions ()
    {
      // Synapse.Utils.Logger.log (this, "search_for_actions");
      /* We are searching for actions => reset target & notify */
      if (model.results[SearchingFor.TARGETS] != null)
      {
        model.clear_searching_for (SearchingFor.TARGETS);
        view.update_targets (model.results[SearchingFor.TARGETS]);
        view.update_focused_target (model.focus[SearchingFor.TARGETS]);
      }
      
      /* No sources => no actions */
      if (model.focus[SearchingFor.SOURCES].value == null)
      {
        model.clear_searching_for (SearchingFor.ACTIONS);
        view.update_actions (model.results[SearchingFor.ACTIONS]);
        view.update_focused_action (model.focus[SearchingFor.ACTIONS]);
        return;
      }
      
      model.results[SearchingFor.ACTIONS] = 
        data_sink.find_actions_for_match (model.focus[SearchingFor.SOURCES].value, model.query[SearchingFor.ACTIONS], qf);
      if (model.results[SearchingFor.ACTIONS].size > 0)
      {
        model.focus[SearchingFor.ACTIONS].value = model.results[SearchingFor.ACTIONS].first();
        // we'll search for targets only when users jumps to searching for actions
      }
      else
      {
        model.focus[SearchingFor.ACTIONS].value = null;
      }
      model.focus[SearchingFor.ACTIONS].key = 0;

      view.update_actions (model.results[SearchingFor.ACTIONS]);
      view.update_focused_action (model.focus[SearchingFor.ACTIONS]);
    }
  }
}
