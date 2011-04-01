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

namespace Synapse.Gui
{
  public class SynapseWindowDoish : GtkCairoBase
  {
    /* Main UI shared components */
    protected NamedIcon match_icon = null;
    protected Label match_label = null;
    protected Label description_label = null;
    protected NamedIcon action_icon = null;
    protected Label action_label = null;
    protected VBox container = null;
    protected VBox container_top = null;
    protected ResultBox results_match = null;
    protected ResultBox results_action = null;
    protected HSelectionContainer results_container = null;
    protected MenuThrobber menuthrobber = null;

    private const int PADDING = 10; // assinged to container_top's border width
    private const int BORDER_RADIUS = 20;
    private const int UI_WIDTH = 420; // height is dynamic
    private const int ICON_SIZE = 128;
    private const int LABEL_SEPARATOR = 20;
    private const int LABEL_SIZE = (UI_WIDTH - LABEL_SEPARATOR * 3) /2;
    private const int IL_DIFFERENCE = ( LABEL_SIZE - ICON_SIZE ) / 2;
    
    /* STATUS */
    private bool list_visible = true;
    
    construct
    {
      window.expose_event.connect (expose_event);
      
      this.searching_for_changed.connect (visual_update_search_for);

      set_list_visible (false);
      visual_update_search_for ();
    }

    ~SynapseWindowDoish ()
    {
      window.destroy ();
    }

    protected override void build_ui ()
    {
      container = new VBox (false, 0);
      window.add (container); 
      
      /* ==> Top container */
      container_top = new VBox (false, 0);
      container_top.set_size_request (UI_WIDTH, -1);
      container_top.border_width = PADDING;
      /* ==> Result box */
      results_container = new HSelectionContainer (null, 0);
      results_container.set_separator_visible (false);
      
      results_match = new ResultBox (UI_WIDTH - 4);
      results_action = new ResultBox (UI_WIDTH - 4);
      results_match.get_match_list_view ().selected_index_changed.connect (this.set_selection_match);
      results_action.get_match_list_view ().selected_index_changed.connect (this.set_selection_action);
      results_match.get_match_list_view ().fire_item.connect (this.command_execute);
      results_action.get_match_list_view ().fire_item.connect (this.command_execute);
      results_container.add (results_match);
      results_container.add (results_action);
      var hbox_result_box = new HBox (true, 0);
      hbox_result_box.border_width = 0;
      hbox_result_box.pack_start (results_container,false,false);
      /* <== Pack */
      container.pack_start (container_top);
      container.pack_start (hbox_result_box,false);
      
      /* Categories - Throbber and menu */ //#0C71D6
      var categories_hbox = new HBox (false, 0);
      container_top.pack_start (categories_hbox, false, true, 0);
      menuthrobber = new MenuThrobber ();
      menuthrobber.set_state (StateType.SELECTED);
      menu = (MenuButton) menuthrobber;
      menuthrobber.set_size_request (22, 22);
      menuthrobber.settings_clicked.connect (()=>{this.show_settings_clicked ();});
      flag_selector.set_state (Gtk.StateType.SELECTED);
      
      var spacer = new Label ("");
      spacer.set_size_request (19,1);
      categories_hbox.pack_start (spacer, false);
      categories_hbox.pack_start (flag_selector);
      categories_hbox.pack_start (menuthrobber, false);
      
      /* Icon Container */
      var icon_hbox = new HBox (true, 0);
      container_top.pack_start (icon_hbox, false, true, 5);
      match_icon = new NamedIcon ();
      var match_icon_sensitive = new SensitiveWidget (match_icon);
      this.make_draggable (match_icon_sensitive);
      match_icon.set_size_request (ICON_SIZE, ICON_SIZE);
      match_icon.set_pixel_size (ICON_SIZE);
      action_icon = new NamedIcon ();
      action_icon.not_found_name = "";
      action_icon.set_size_request (ICON_SIZE, ICON_SIZE);
      action_icon.set_pixel_size (ICON_SIZE);
      
      match_icon.set_icon_name ("Synapse", Gtk.IconSize.DIALOG);
      action_icon.set_icon_name ("Synapse", Gtk.IconSize.DIALOG);
      
      icon_hbox.pack_start (match_icon_sensitive, false, false);
      icon_hbox.pack_start (action_icon, false, false);
      
      /* Match Label container */
      var labels_hbox = new HBox (true, 0);
      container_top.pack_start (labels_hbox, false, true, 0);
      match_label = new Label ("");
      match_label.single_line_mode = true;
      match_label.ellipsize = Pango.EllipsizeMode.END;
      match_label.set_alignment (0.5f, 0.0f);
      match_label.set_state (Gtk.StateType.SELECTED);
      match_label.set_size_request (LABEL_SIZE, -1);
      match_label.xpad = 5;
      action_label = new Label ("");
      action_label.single_line_mode = true;
      action_label.ellipsize = Pango.EllipsizeMode.END;
      action_label.set_alignment (0.5f, 0.0f);
      action_label.set_state (Gtk.StateType.SELECTED);
      action_label.set_size_request (LABEL_SIZE, -1);
      action_label.xpad = 5;
      
      labels_hbox.pack_start (match_label, false, false);
      labels_hbox.pack_start (action_label, false, false);
      
      spacer = new Label ("");
      spacer.set_size_request (1, 14);
      container_top.pack_start (spacer, false, false, 0);
      
      description_label = new Label ("Find the difference!! - Is this really Gnome-Do?");
      description_label.single_line_mode = true;
      description_label.ellipsize = Pango.EllipsizeMode.END;
      description_label.set_alignment (0.5f, 1.0f);
      description_label.ypad = 0;
      description_label.set_state (Gtk.StateType.SELECTED);
      container_top.pack_start (description_label, false, true, 0);
      
      spacer = new Label ("");
      spacer.set_size_request (1, SHADOW_SIZE);
      container_top.pack_start (spacer, false, false, 0);
      
      container.show_all ();
    }
    protected override bool show_list (bool visible)
    {
      if (list_visible == visible) return false;
      set_list_visible (visible);
      return true;
    }
    private void visual_update_search_for ()
    {
      if (searching_for_matches)
      {
        results_container.select (0);
      }
      else
      {
        results_container.select (1);
      }
      window.queue_draw ();
    }

    protected override void on_composited_changed (Widget w)
    {
      base.on_composited_changed (w);
      if (w.is_composited ())
        container.border_width = SHADOW_SIZE;
      else
        container.border_width = 2;
    }
    
    protected override void set_input_mask ()
    {
      Requisition req = {0, 0};
      window.size_request (out req);
      int w = req.width, h = req.height;
      bool composited = window.is_composited ();
      var bitmap = new Gdk.Pixmap (null, w, h, 1);
      var ctx = Gdk.cairo_create (bitmap);
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();
      ctx.set_source_rgba (0, 0, 0, 1);
      ctx.set_operator (Cairo.Operator.SOURCE);
      if (composited)
      {
        Utils.cairo_rounded_rect (ctx, 0, 0,
                                       container_top.allocation.width + SHADOW_SIZE * 2, 
                                       list_visible ?
                                       h : container_top.allocation.height + SHADOW_SIZE * 2,
                                       BORDER_RADIUS);
        ctx.fill ();
        add_kde_compatibility (window, w, h);
      }
      else
      {
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.paint ();
      }
      window.input_shape_combine_mask (null, 0, 0);
      window.input_shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
    }
    
    protected virtual bool expose_event (Widget widget, Gdk.EventExpose event) {
      bool comp = widget.is_composited ();
      Cairo.Context ctx = Gdk.cairo_create (widget.window);
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Operator.OVER);
      double w = container_top.allocation.width;
      double h = container_top.allocation.height - SHADOW_SIZE;
      double x = container_top.allocation.x;
      double y = container_top.allocation.y;
      
      double r = 0, b = 0, g = 0;
      if (comp)
      {
        // shadow
        if (this.list_visible)
        {
          //draw shadow for match list
          var sp = SHADOW_SIZE + BORDER_RADIUS;
          Utils.cairo_make_shadow_for_rect (ctx, results_container.allocation.x,
                                                 results_container.allocation.y - sp,
                                                 results_container.allocation.width,
                                                 results_container.allocation.height + sp,
                                                 0, r, g, b, SHADOW_SIZE);
          //draw background for match list
          ctx.rectangle (results_container.allocation.x,
                         results_container.allocation.y - sp,
                         results_container.allocation.width,
                         results_container.allocation.height + sp);
          ch.set_source_rgba (ctx, 1.0, ch.StyleType.BASE, StateType.NORMAL);
          ctx.fill ();
        }
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, BORDER_RADIUS,
                                          r, g, b, SHADOW_SIZE);
      }
      ctx.save ();
      // pattern
      Pattern pat = new Pattern.linear(0, y, 0, y+h);
      r = g = b = 0.15;
      ch.get_color_colorized (ref r, ref g, ref b, ch.StyleType.BG, StateType.SELECTED);
      pat.add_color_stop_rgba (0.0, r, g, b, 0.95);
      r = g = b = 0.5;
      ch.get_color_colorized (ref r, ref g, ref b, ch.StyleType.BG, StateType.SELECTED);
      pat.add_color_stop_rgba (1.0, r, g, b, 1.0);
      _cairo_path_for_main (ctx, comp, x, y, w, h);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      
      // icon bgs
       
      ctx.save ();
      Utils.cairo_rounded_rect (ctx, this.match_icon.allocation.x - IL_DIFFERENCE,
                                     this.match_icon.allocation.y - 6,
                                     LABEL_SIZE,
                                     this.match_label.allocation.y -
                                          this.match_icon.allocation.y +
                                          this.match_label.allocation.height + 12,
                                     BORDER_RADIUS / 2);
      ch.set_source_rgba (ctx, this.searching_for_matches ? 0.3 : 0.08, ch.StyleType.FG, StateType.SELECTED);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      ctx.save ();
      Utils.cairo_rounded_rect (ctx, this.action_icon.allocation.x - IL_DIFFERENCE,
                                     this.action_icon.allocation.y - 6,
                                     LABEL_SIZE,
                                     this.action_label.allocation.y -
                                          this.action_icon.allocation.y +
                                          this.action_label.allocation.height + 12,
                                     BORDER_RADIUS / 2);
      ch.set_source_rgba (ctx, !this.searching_for_matches ? 0.3 : 0.08, ch.StyleType.FG, StateType.SELECTED);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      
      // top light      
      ctx.save ();
      _cairo_path_for_main (ctx, comp, x, y, w, h);
      ctx.clip ();
      ctx.set_operator (Operator.OVER);
      ctx.new_path ();
      ctx.move_to (x, y);
      ctx.rel_line_to (0.0, h / 3.0);
      ctx.rel_curve_to (w / 4.0, -h / 10.0, w / 4.0 * 3.0, -h / 10.0, w, 0.0);
      ctx.rel_line_to (0.0, -h / 3.0);
      ctx.close_path ();
      pat = new Pattern.linear (0, y + h / 10.0, 0, y + h / 3.0);
      ch.add_color_stop_rgba (pat, 0.0, 0.0, ch.StyleType.FG, StateType.SELECTED);
      ch.add_color_stop_rgba (pat, 1.0, 0.4, ch.StyleType.FG, StateType.SELECTED);
      ctx.set_source (pat);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      /* Propagate Expose */               
      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
    }

    private void _cairo_path_for_main (Cairo.Context ctx, bool composited,
                                       double x, double y, double w, double h)
    {
      

      if (composited)
        Utils.cairo_rounded_rect (ctx, x, y, w, h, BORDER_RADIUS);
      else
      {
        w = container.allocation.width;
        h = container.allocation.height;
        x = container.allocation.x;
        y = container.allocation.y;
        ctx.rectangle (x, y, w, h);
      }
    }
    
    protected override void clear_search_or_hide_pressed ()
    {
      base.clear_search_or_hide_pressed ();
      if (get_match_search () == "") set_list_visible (false);
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
    
    private string get_description_markup (string s)
    {
      // FIXME: i18n
      if (s == "") return "<span size=\"small\"> </span>";

      return Utils.markup_string_with_search (Utils.replace_home_path_with (s, "Home", " > "),
                                             get_match_search (),
                                             "small");
    }

    /* UI INTERFACE IMPLEMENTATION */
    protected override void set_throbber_visible (bool visible)
    {
      if (visible)
        menuthrobber.active = true;
      else
        menuthrobber.active = false;
    }
    
    private string get_down_to_see_recent ()
    {
      if (DOWN_TO_SEE_RECENT == "") return TYPE_TO_SEARCH;
      return "%s (%s)".printf (TYPE_TO_SEARCH, DOWN_TO_SEE_RECENT);
    }
    protected override void focus_match ( int index, Match? match )
    {
      string size = "medium";
      if (match == null)
      {
        /* Show default stuff */
        if (!is_in_initial_status ())
        {
          if (is_searching_for_recent ())
          {
            match_label.set_markup (
                Markup.printf_escaped ("<span size=\"%s\">%s</span>",
                                       size, " "));
            description_label.set_markup (
              get_description_markup (menuthrobber.active ? SEARCHING : NO_RECENT_ACTIVITIES)
            );
          }
          else
          {
            match_label.set_markup (
                Markup.printf_escaped ("<span size=\"%s\">%s</span>",
                                       size, get_match_search ()));
            description_label.set_markup (
              get_description_markup (menuthrobber.active ? SEARCHING : NO_RESULTS)
            );
          }
          match_icon.set_icon_name ("search", IconSize.DIALOG);
        }
        else
        {
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_label.set_markup (
                Markup.printf_escaped ("<span size=\"%s\">%s</span>",
                                       size, " "));
          description_label.set_markup (
            Markup.printf_escaped ("<span size=\"small\">%s</span>",
                                   get_down_to_see_recent ()));
        }
      }
      else
      {
        if (match.has_thumbnail)
          match_icon.set_icon_name (match.thumbnail_path, IconSize.DIALOG);
        else
          match_icon.set_icon_name (match.icon_name, IconSize.DIALOG);

        match_label.set_markup (Utils.markup_string_with_search (match.title, get_match_search (), size, true));
        description_label.set_markup (get_description_markup (match.description));
      }
      results_match.move_selection_to_index (index);
    }
    protected override void handle_empty_updated ()
    {
      if (description_label != null && is_in_initial_status ())
        description_label.set_markup (
            Markup.printf_escaped ("<span size=\"small\">%s</span>",
                                   get_down_to_see_recent ()));
    }
    protected override void focus_action ( int index, Match? action )
    {
      string size = "medium";
      if (action == null)
      {
        action_icon.set_icon_name ("", IconSize.DIALOG);
        if (searching_for_matches)
          action_label.set_markup (
                Markup.printf_escaped ("<span size=\"%s\">%s</span>",
                                       size, " "));
        else
        {
          action_label.set_markup (Utils.markup_string_with_search ("", get_action_search(), size));
          description_label.set_text (get_description_markup (NO_RESULTS));
        }
      }
      else
      {
        action_icon.set_icon_name (action.icon_name, IconSize.DIALOG);
        action_label.set_markup (Utils.markup_string_with_search (action.title,
                                 searching_for_matches ? 
                                 "" : get_action_search (), size));
        if (!searching_for_matches) description_label.set_markup (get_description_markup (action.description));
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
