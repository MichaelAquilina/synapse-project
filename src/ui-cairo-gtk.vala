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
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;
using Synapse.Utils;

namespace Synapse
{
  public class SynapseWindow : UIInterface
  {
    Window window;
    bool searching_for_matches = true;
    
    /* Main UI shared components */
    protected NamedIcon match_icon = null;
    protected NamedIcon match_icon_thumb = null;
    protected NamedIcon action_icon = null;
    protected ContainerOverlayed match_icon_container_overlayed = null;
    
    protected ShrinkingLabel main_label_description = null;
    protected ShrinkingLabel main_label = null;
    protected ShrinkingLabel secondary_label = null;

    protected HTextSelector flag_selector = null;
    protected HBox container_top = null;
    protected VBox vcontainer_top = null;
    protected VBox container = null;
    
    protected HSelectionContainer results_container = null;

    protected ResultBox results_match = null;
    protected ResultBox results_action = null;
    
    protected Synapse.Throbber throbber = null;
    protected Synapse.MenuButton pref = null;
    
    private const int UI_WIDTH = 620; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 8; // assigned to containers's border width in composited
    private const int SECTION_PADDING = 10;
    private const int BORDER_RADIUS = 10;
    private const int ICON_SIZE = 160;
    private const int TOP_SPACING = ICON_SIZE / 2;
    private const int ACTION_ICON_DISPLACEMENT = ICON_SIZE / 8;
    private const int LABEL_INTERNAL_PADDING = 4;
    private const string LABEL_TEXT_SIZE = "x-large";
    private const string DESCRIPTION_TEXT_SIZE = "medium";
    
    private string[] categories =
    {
      "Actions",
      "Audio",
      "Applications",
      "All",
      "Documents",
      "Images",
      "Video",
      "Internet"
    };
    private QueryFlags[] categories_query =
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

    /* STATUS */
    private bool list_visible = true;
    private IMContext im_context;
    
    construct
    {
      window = new Window ();
      window.skip_taskbar_hint = true;
      window.skip_pager_hint = true;
      window.set_position (WindowPosition.CENTER);
      window.set_decorated (false);
      window.set_resizable (false);
      window.notify["is-active"].connect (()=>{
        if (!window.is_active && !pref.is_menu_visible ())
        {
          hide ();
        }
      }); 
      
      build_ui ();

      Utils.ensure_transparent_bg (window);
      window.expose_event.connect (expose_event);
      on_composited_changed (window);
      window.composited_changed.connect (on_composited_changed);

      window.key_press_event.connect (key_press_event);

      set_list_visible (false);
      
      /* SEZEN */
      focus_match (0, null);
      focus_action (0, null);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_char);
      im_context.focus_in ();
    }

    ~SynapseWindow ()
    {
      window.destroy ();
    }

    protected virtual void build_ui ()
    {
      /* containers holds top hbox and result list */
      container = new VBox (false, 0);
      container.border_width = SHADOW_SIZE;
      window.add (container);
      
      vcontainer_top = new VBox (false, 0);
      vcontainer_top.border_width = BORDER_RADIUS;
      
      container_top = new HBox (false, 0);
      vcontainer_top.set_size_request (UI_WIDTH, -1);
      
      
      vcontainer_top.pack_start (container_top);
      container.pack_start (vcontainer_top, false);
      
      /* Action Icon */
      action_icon = new NamedIcon ();
      action_icon.set_pixel_size (ICON_SIZE * 29 / 100);
      action_icon.set_alignment (0.5f, 0.5f);
      /* Match Icon packed into container_top */
      match_icon_container_overlayed = new ContainerOverlayed();
      match_icon_thumb = new NamedIcon();
      match_icon_thumb.set_pixel_size (ICON_SIZE / 2);
      match_icon = new NamedIcon ();
      match_icon.set_alignment (0.0f, 0.5f);
      match_icon.set_pixel_size (ICON_SIZE);
      match_icon_container_overlayed.set_size_request (ICON_SIZE + ACTION_ICON_DISPLACEMENT, ICON_SIZE);
      match_icon_container_overlayed.set_scale_for_pos (0.3f, ContainerOverlayed.Position.BOTTOM_RIGHT);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon, ContainerOverlayed.Position.MAIN);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon_thumb, ContainerOverlayed.Position.BOTTOM_LEFT);
      match_icon_container_overlayed.set_widget_in_position 
            (action_icon, ContainerOverlayed.Position.BOTTOM_RIGHT);
      container_top.pack_start (match_icon_container_overlayed, false);
      
      /* Throbber */
      throbber = new Throbber ();
      throbber.set_size_request (18, 18);

      /* Match or Action Label */
      main_label = new ShrinkingLabel ();
      main_label.xpad = LABEL_INTERNAL_PADDING;
      main_label.set_alignment (0.0f, 1.0f);
      main_label.set_ellipsize (Pango.EllipsizeMode.END);
      var fakeinput = new FakeInput ();
      fakeinput.border_radius = 5;
      {
        var hbox = new HBox (false, 0);
        hbox.border_width = LABEL_INTERNAL_PADDING;
        hbox.pack_start (main_label);
        hbox.pack_start (throbber, false, false);
        fakeinput.add (hbox);
      }
      
      /* Query flag selector  */
      flag_selector = new HTextSelector();
      foreach (string s in this.categories)
      {
        flag_selector.add_text (s);
      }
      flag_selector.selected = 3;
      
      /* Description */
      main_label_description = new ShrinkingLabel ();
      main_label_description.set_alignment (0.0f, 1.0f);
      main_label_description.set_ellipsize (Pango.EllipsizeMode.END);
      main_label_description.xpad = LABEL_INTERNAL_PADDING * 2;
      secondary_label = new ShrinkingLabel ();
      secondary_label.set_alignment (1.0f, 1.0f);
      secondary_label.set_ellipsize (Pango.EllipsizeMode.START);
      secondary_label.xpad = LABEL_INTERNAL_PADDING * 2;
      
      /* MenuThrobber item */
      pref = new MenuButton ();
      pref.button_scale = 1.0;
      pref.settings_clicked.connect (()=>{this.show_settings_clicked ();});
      pref.set_size_request (10, 10);
      {
        var main_vbox = new VBox (false, 0);
        var hbox = new HBox (false, 0);
        var vbox = new VBox (false, 0);
        
        main_vbox.pack_start (new Label(null));
        main_vbox.pack_start (hbox, false);
        container_top.pack_start (main_vbox);
        
        vbox.pack_start (flag_selector, false);
        vbox.pack_start (new HSeparator (), false);
        vbox.pack_start (fakeinput, false);
        hbox.pack_start (vbox);
        hbox.pack_start (pref, false, false);
      }

      {
        var hbox = new HBox (false, 0);
        secondary_label.set_size_request (ICON_SIZE + ACTION_ICON_DISPLACEMENT, -1);
        hbox.pack_start (secondary_label, false);
        hbox.pack_start (main_label_description);
        vcontainer_top.pack_start (hbox, false, true, 5);
      }
      
      results_container = new HSelectionContainer (null, 0);
      results_container.set_separator_visible (false);
      container.pack_start (results_container, false);
      
      results_match = new ResultBox (UI_WIDTH - 2);
      results_action = new ResultBox (UI_WIDTH - 2);
      results_container.add (results_match);
      results_container.add (results_action);
      
      /* Prepare colors using label */
      ColorHelper.get_default ().init_from_widget_type (typeof (Label));
      window.style_set.connect (()=>{
        ColorHelper.get_default ().init_from_widget_type (typeof (Label));
        window.queue_draw ();
      });
      
      container.show_all ();
    }
    
    private void set_list_visible (bool b)
    {
      if (b == list_visible)
        return;
      list_visible = b;
      results_container.visible = b;
      set_input_mask ();
      window.queue_draw ();
    }
    
    protected virtual void on_composited_changed (Widget w)
    {
      Gdk.Screen screen = w.get_screen ();
      bool comp = screen.is_composited ();
      this.hide_and_reset ();
      Gdk.Colormap? cm = screen.get_rgba_colormap();
      if (cm == null)
      {
        comp = false;
        cm = screen.get_rgb_colormap();
      }
      debug ("Screen is%s composited.", comp?"": " NOT");
      w.set_colormap (cm);
      if (comp)
        container.border_width = SHADOW_SIZE;
      else
        container.border_width = 1;
    }
    public bool expose_event (Widget widget, Gdk.EventExpose event)
    {
      bool comp = widget.is_composited ();
      var ctx = Gdk.cairo_create (widget.get_window ());
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      ctx.translate (0.5, 0.5);
      Utils.ColorHelper ch = Utils.ColorHelper.get_default ();
      double border_radius = comp ? BORDER_RADIUS : 0;
      double x = this.container.border_width,
             y = flag_selector.allocation.y - border_radius;
      double w = UI_WIDTH - 1.0,
             h = main_label_description.allocation.y - y + main_label_description.allocation.height + border_radius - 1.0;
      if (!comp)
      {
        y = this.container.border_width;
        h = vcontainer_top.allocation.height;
      }
      ctx.set_operator (Operator.OVER);
      
      /* Prepare shadow color */
      double r = 0, b = 0, g = 0;
      ch.get_rgb (out r, out g, out b, ch.StyleType.BG, StateType.NORMAL, ch.Mod.INVERTED);

      if (list_visible)
      {
        double ly = y + h - border_radius;
        double lh = results_container.allocation.y - ly + results_container.allocation.height;
        ctx.rectangle (x, ly, w, lh);
        ch.set_source_rgba (ctx, 1.0, ch.StyleType.BASE, StateType.NORMAL);
        ctx.fill ();
        if (comp)
        {
          //draw shadow
          Utils.cairo_make_shadow_for_rect (ctx, x, ly, w, lh, 0,
                                            r, g, b, 0.9, SHADOW_SIZE);
        }
      }
      if (comp)
      {
        //draw shadow
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, border_radius,
                                          r, g, b, 0.9, SHADOW_SIZE);
      }
      ctx.set_operator (Operator.SOURCE);
      Pattern pat = new Pattern.linear(0, y, 0, y + h);
      ch.add_color_stop_rgba (pat, 0, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.LIGHTER);
      ch.add_color_stop_rgba (pat, 0.75, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.NORMAL);
      ch.add_color_stop_rgba (pat, 1, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.DARKER);
      Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
      ctx.set_source (pat);
      ctx.save ();
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      if (comp)
      {
        // border
        Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
        ch.set_source_rgba (ctx, 0.6, ch.StyleType.BG, StateType.NORMAL, ch.Mod.INVERTED);
        ctx.set_line_width (1.0);
        ctx.stroke ();
      }

      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
    }
    
    protected virtual void set_input_mask ()
    {
      Requisition req = {0, 0};
      window.size_request (out req);
      bool composited = window.is_composited ();
      var bitmap = new Gdk.Pixmap (null, req.width, req.height, 1);
      var ctx = Gdk.cairo_create (bitmap);
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();
      ctx.set_source_rgba (0, 0, 0, 1);
      ctx.set_operator (Cairo.Operator.SOURCE);
      if (composited)
      {
        Utils.cairo_rounded_rect (ctx, match_icon_container_overlayed.allocation.x,
                                       match_icon_container_overlayed.allocation.y,
                                       match_icon_container_overlayed.allocation.width,
                                       match_icon_container_overlayed.allocation.height, 0);
        ctx.fill ();
        double x = this.container.border_width,
               y = flag_selector.allocation.y - BORDER_RADIUS;
        double w = UI_WIDTH,
               h = main_label_description.allocation.y - y + main_label_description.allocation.height + BORDER_RADIUS;
        Utils.cairo_rounded_rect (ctx, x - SHADOW_SIZE, y - SHADOW_SIZE,
                                       w + SHADOW_SIZE * 2, 
                                       h + SHADOW_SIZE * 2,
                                       SHADOW_SIZE);
        ctx.fill ();
        if (list_visible)
        {
          ctx.rectangle (0,
                         y + h,
                         req.width,
                         req.height - (y + h));
          ctx.fill ();
        }
      }
      else
      {
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.paint ();
      }
      window.input_shape_combine_mask (null, 0, 0);
      window.input_shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
    }

    private void search_add_char (string chr)
    {
      if (searching_for_matches)
      {
        set_match_search (get_match_search() + chr);
        set_action_search ("");
      }
      else
        set_action_search (get_action_search() + chr);
    }
    private void search_delete_char ()
    {
      string s = "";
      if (searching_for_matches)
        s = get_match_search ();
      else
        s = get_action_search ();
      long len = s.length;
      if (len > 0)
      {
        s = s.substring (0, len - 1);
        if (searching_for_matches)
        {
          set_match_search (s);
          set_action_search ("");
          if (s == "")
            set_list_visible (false);
        }
        else
          set_action_search (s);
      }
    }
    private void visual_update_search_for ()
    {
      if (searching_for_matches)
      {
        match_icon.set_sensitive (true);
        results_container.select (0);
      }
      else
      {
        match_icon.set_sensitive (false);
        results_container.select (1);
      }
      focus_current_action ();
      focus_current_match ();
      window.queue_draw ();
    }
    private void hide_and_reset ()
    {
      window.hide ();
      set_list_visible (false);
      flag_selector.selected = 3;
      searching_for_matches = true;
      visual_update_search_for ();
      reset_search ();
    }
    protected virtual bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      CommandTypes command = get_command_from_key_event (event);

      switch (command)
      {
        case CommandTypes.EXECUTE:
          if (execute ())
            hide_and_reset ();
          break;
        case CommandTypes.SEARCH_DELETE_CHAR:
          search_delete_char ();
          break;
        case CommandTypes.CLEAR_SEARCH_OR_HIDE:
          if (!searching_for_matches)
          {
            set_action_search ("");
            searching_for_matches = true;
            visual_update_search_for ();
            Match m = null;
            int i = 0;
            get_match_focus (out i, out m);
            focus_match (i, m);
            window.queue_draw ();
          }
          else if (get_match_search() != "")
          {
            set_match_search("");
            set_list_visible (false);
          }
          else
          {
            hide_and_reset ();
          }
          break;
        case CommandTypes.PREV_CATEGORY:
          flag_selector.select_prev ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            visual_update_search_for ();
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[flag_selector.selected]);
          break;
        case CommandTypes.NEXT_CATEGORY:
          flag_selector.select_next ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            visual_update_search_for ();
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[flag_selector.selected]);
          break;
        case CommandTypes.FIRST_RESULT:
          if (searching_for_matches)
            select_first_last_match (true);
          else
            select_first_last_action (true);
          break;
        case CommandTypes.LAST_RESULT:
          if (!list_visible)
          {
            set_list_visible (true);
            return true;
          }
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
          if (!b)
            set_list_visible (false);
          break;
        case CommandTypes.PREV_PAGE:
          bool b = true;
          if (searching_for_matches)
            b = move_selection_match (-5);
          else
            b = move_selection_action (-5);
          if (!b)
            set_list_visible (false);
          break;
        case CommandTypes.NEXT_RESULT:
          if (!list_visible)
          {
            set_list_visible (true);
            return true;
          }
          if (searching_for_matches)
            move_selection_match (1);
          else
            move_selection_action (1);
          set_list_visible (true);
          break;
        case CommandTypes.NEXT_PAGE:
          if (!list_visible)
          {
            set_list_visible (true);
            return true;
          }
          if (searching_for_matches)
            move_selection_match (5);
          else
            move_selection_action (5);
          set_list_visible (true);
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
          Match m = null;
          int i = 0;
          if (searching_for_matches)
          {
            get_match_focus (out i, out m);
            focus_match (i, m);
          }
          else
          {
            get_action_focus (out i, out m);
            focus_action (i, m);
          }
          visual_update_search_for ();
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
      window.show ();
      set_input_mask ();
    }
    public override void hide ()
    {
      hide_and_reset ();
    }
    public override void present_with_time (uint32 timestamp)
    {
      window.present_with_time (timestamp);
    }    
    protected override void set_throbber_visible (bool visible)
    {
      if (visible)
        throbber.active = true;
      else
        throbber.active = false;
    }
    protected override void focus_match ( int index, Match? match )
    {
      if (match == null)
      {
        if (get_match_search () != "")
        {
          if (searching_for_matches)
          {
            main_label.set_markup (Utils.markup_string_with_search ("", get_match_search (), LABEL_TEXT_SIZE));
            main_label_description.set_markup (Utils.markup_string_with_search ("Not Found.", "", DESCRIPTION_TEXT_SIZE));
          }
          //else -> impossible!

          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
        else
        {
          /* Show default stuff */
          if (searching_for_matches)
          {
            main_label.set_markup (
            Markup.printf_escaped ("<span size=\"%s\">%s</span>", LABEL_TEXT_SIZE,
                                   "Type to search..."));
            main_label_description.set_markup (Utils.markup_string_with_search ("", "", "small"));
          }
          //else -> impossible
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
      }
      else
      {
        match_icon.set_icon_name (match.icon_name, IconSize.DIALOG);
        if (match.has_thumbnail)
          match_icon_thumb.set_icon_name (match.thumbnail_path, IconSize.DIALOG);
        else
          match_icon_thumb.clear ();

        if (searching_for_matches)
        {
          main_label.set_markup (Utils.markup_string_with_search (match.title, get_match_search (), LABEL_TEXT_SIZE));
          main_label_description.set_markup (
            Utils.markup_string_with_search (Utils.replace_home_path_with (match.description, "Home", " > "),
                                             get_match_search (),
                                             DESCRIPTION_TEXT_SIZE));
        }
        else
        {
          secondary_label.set_markup (Utils.markup_string_with_search (match.title, "", DESCRIPTION_TEXT_SIZE));
        }
      }
      results_match.move_selection_to_index (index);
    }
    protected override void focus_action ( int index, Match? action )
    {
      if (action == null)
      {
        action_icon.hide ();
        action_icon.set_icon_name ("system-run", IconSize.DIALOG);
        if (!searching_for_matches)
        {
          main_label.set_markup (Utils.markup_string_with_search ("", get_action_search(), LABEL_TEXT_SIZE));
          main_label_description.set_markup (Utils.markup_string_with_search ("Not Found.", "", DESCRIPTION_TEXT_SIZE));
        }
        else
        {
          secondary_label.set_markup (Utils.markup_string_with_search (" ", "", DESCRIPTION_TEXT_SIZE));
        }
      }
      else
      {
        action_icon.show ();
        action_icon.set_icon_name (action.icon_name, IconSize.DIALOG);
        if (!searching_for_matches)
        {
          main_label.set_markup (Utils.markup_string_with_search (action.title, get_action_search (), LABEL_TEXT_SIZE));
          main_label_description.set_markup (Utils.markup_string_with_search (action.description, get_action_search (), DESCRIPTION_TEXT_SIZE));
        }
        else
        {
          secondary_label.set_markup (Utils.markup_string_with_search (action.title, "", DESCRIPTION_TEXT_SIZE));
        }
      }
      results_action.move_selection_to_index (index);
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      results_match.update_matches (matches);
      focus_match ( index, match );
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      results_action.update_matches (actions);
      focus_action ( index, action );
    }
  }
}
