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
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;
using Synapse.Gui.Utils;

namespace Synapse.Gui
{
  public class SynapseWindowTwoLines : GtkCairoBase
  {
    /* Main UI shared components */
    protected NamedIcon match_icon = null;
    protected NamedIcon match_icon_thumb = null;
    protected ShrinkingLabel match_label = null;
    protected Label match_label_description = null;
    protected NamedIcon action_icon = null;
    protected ShrinkingLabel action_label = null;
    protected HBox top_hbox = null;
    protected FakeInput fake_input_match = null;
    protected FakeInput fake_input_action = null;
    protected Label top_spacer = null;
    protected VBox container = null;
    protected VBox container_top = null;
    protected ContainerOverlayed match_icon_container_overlayed = null;
    protected ResultBox results_match = null;
    protected ResultBox results_action = null;
    protected HSelectionContainer results_container = null;
    protected MenuThrobber menuthrobber = null;

    private const int UI_WIDTH = 600; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int BORDER_RADIUS = 20;
    private const int ICON_SIZE = 172;
    private const int ACTION_ICON_SIZE = 48;
    
    /* STATUS */
    private bool list_visible = true;
    
    construct
    {
      window.expose_event.connect (expose_event);
      
      this.searching_for_changed.connect (visual_update_search_for);

      set_list_visible (false);
      visual_update_search_for ();
    }

    ~SynapseWindowTwoLines ()
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
      
      results_match = new ResultBox (450);
      results_action = new ResultBox (450);
      results_container.add (results_match);
      results_container.add (results_action);
      var hbox_result_box = new HBox (true, 0);
      hbox_result_box.pack_start (results_container,false,false);
      /* <== Pack */
      container.pack_start (container_top);
      container.pack_start (hbox_result_box,false);

      /* Top Hbox */
      top_hbox = new HBox (false, 0);
      /* Match Description */
      match_label_description = new Label (null);
      match_label_description.set_alignment (0, 0);
      match_label_description.set_ellipsize (Pango.EllipsizeMode.END); 
      match_label_description.set_line_wrap (true);
      match_label_description.xpad = 6;
      /* Packing Top Hbox with Match Desctiption into Top VBox*/
      container_top.pack_start (top_hbox);
      
      /* Match Icon packed into Top HBox */
      match_icon_container_overlayed = new ContainerOverlayed();
      match_icon_thumb = new NamedIcon();
      match_icon_thumb.set_pixel_size (ICON_SIZE / 2);
      match_icon = new NamedIcon ();
      match_icon.set_size_request (ICON_SIZE, ICON_SIZE);
      match_icon.set_pixel_size (ICON_SIZE);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon, ContainerOverlayed.Position.MAIN);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon_thumb, ContainerOverlayed.Position.BOTTOM_LEFT);
      top_hbox.pack_start (match_icon_container_overlayed, false);
      
      /* VBox to push down the right area */
      var top_right_vbox = new VBox (false, 0);
      top_hbox.pack_start (top_right_vbox);
      /* Top Spacer */
      top_spacer = new Label(null);
      /* flag_selector */
      flag_selector = new HTextSelector();
      foreach (string s in this.categories)
      {
        flag_selector.add_text (s);
      }
      flag_selector.selected = 3;

      /* Throbber and menu */
      menuthrobber = new MenuThrobber ();
      menu = (MenuButton) menuthrobber;
      menuthrobber.set_size_request (ACTION_ICON_SIZE, 22);
      menuthrobber.settings_clicked.connect (()=>{this.show_settings_clicked ();});
      /* HBox for titles and action icon */
      var right_hbox = new HBox (false, 0);
      /* HBox for menuthrobber and flag_selector */
      var topright_hbox = new HBox (false, 0);
      
      {
        var vbox = new VBox (false, 0);
        vbox.pack_start (flag_selector);
        vbox.pack_start (new Gtk.HSeparator (), false);
        topright_hbox.pack_start (vbox);
      }
      topright_hbox.pack_start (menuthrobber, false);

      top_right_vbox.pack_start (top_spacer, true);
      top_right_vbox.pack_start (topright_hbox, false);
      top_right_vbox.pack_start (right_hbox, false);
      top_right_vbox.pack_start (match_label_description, false);
      
      /* Titles box and Action icon*/
      var labels_hbox = new VBox (false, 0);
      action_icon = new NamedIcon ();
      action_icon.set_pixel_size (ACTION_ICON_SIZE);
      action_icon.set_alignment (0.5f, 0.5f);
      action_icon.set_size_request (ACTION_ICON_SIZE, ACTION_ICON_SIZE);

      fake_input_action = new FakeInput ();
      fake_input_match = new FakeInput ();
      fake_input_action.left_padding = fake_input_match.left_padding = 6;
      fake_input_action.right_padding = fake_input_match.right_padding = 6;
      fake_input_action.bottom_padding = 3;
      
      right_hbox.pack_start (labels_hbox);
      right_hbox.pack_start (action_icon, false);
      
      match_label = new ShrinkingLabel ();
      match_label.set_alignment (0.0f, 0.5f);
      match_label.set_ellipsize (Pango.EllipsizeMode.END);
      match_label.xpad = 10;
      match_label.ypad = 3;

      action_label = new ShrinkingLabel ();
      action_label.set_alignment (1.0f, 0.5f);
      match_label.set_ellipsize (Pango.EllipsizeMode.START);
      action_label.xpad = 10;
      action_label.ypad = 3;
      
      fake_input_action.add (action_label);
      fake_input_match.add (match_label);
      
      labels_hbox.pack_start (fake_input_match, false);
      labels_hbox.pack_start (fake_input_action, false);
      
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
        fake_input_match.input_alpha = 1.0;
        fake_input_action.input_alpha = 0.1;
        results_container.select (0);
      }
      else
      {
        fake_input_match.input_alpha = 0.1;
        fake_input_action.input_alpha = 1.0;
        results_container.select (1);
      }
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
        int spacing = top_spacer.allocation.height;
        Utils.cairo_rounded_rect (ctx, SHADOW_SIZE, SHADOW_SIZE,
                                       ICON_SIZE + PADDING * 2,
                                       ICON_SIZE, BORDER_RADIUS);
        ctx.fill ();
        Utils.cairo_rounded_rect (ctx, 0, spacing,
                                       container_top.allocation.width + SHADOW_SIZE * 2, 
                                       container_top.allocation.height + SHADOW_SIZE * 2 - spacing,
                                       BORDER_RADIUS);
        ctx.fill ();
        if (list_visible)
        {
          results_container.size_request (out req);
              
          ctx.rectangle ((w - req.width) / 2,
                         container_top.allocation.height,
                         req.width,
                         h - container_top.allocation.height);
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
    
    protected virtual bool expose_event (Widget widget, Gdk.EventExpose event) {
      bool comp = widget.is_composited ();
      var ctx = Gdk.cairo_create (widget.window);
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Operator.OVER);
      ctx.translate (0.5, 0.5);
      double w = container_top.allocation.width - 1;
      double h = container_top.allocation.height - 1;
      double x = container_top.allocation.x;
      double y = container_top.allocation.y;
      if (comp)
      {
        int spacing = top_spacer.allocation.height;
        y += spacing;
        h -= spacing;
        double r = 0, b = 0, g = 0;
        //draw black shadow
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, BORDER_RADIUS,
                                          r, g, b, SHADOW_SIZE);
        // border
        _cairo_path_for_main (ctx, comp, x, y, w, h);
        ctx.set_source_rgba (r, g, b, 0.6);
        ctx.set_line_width (1);
        ctx.stroke ();
        if (this.list_visible)
        {
          //draw shadow
          Utils.cairo_make_shadow_for_rect (ctx, results_container.allocation.x,
                                                 results_container.allocation.y,
                                                 results_container.allocation.width,
                                                 results_container.allocation.height,
                                                 0, r, g, b, SHADOW_SIZE);
          ctx.rectangle (results_container.allocation.x,
                         results_container.allocation.y,
                         results_container.allocation.width,
                         results_container.allocation.height);
          ctx.set_source_rgba (r, g, b, 0.6);
          ctx.set_line_width (2.5);
          ctx.stroke ();
        }
      }
      ctx.save ();
      Pattern pat = new Pattern.linear(0, y, 0, y+h);
      ch.add_color_stop_rgba (pat, 0, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.LIGHTER);
      ch.add_color_stop_rgba (pat, 0.75, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.NORMAL);
      ch.add_color_stop_rgba (pat, 1, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.DARKER);

      _cairo_path_for_main (ctx, comp, x, y, w, h);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      if (!comp)
      {
        //border for non composited
        ctx.set_operator (Operator.OVER);
        _cairo_path_for_main (ctx, comp, x, y, w, h);
        ch.set_source_rgba (ctx, 1.0, ch.StyleType.FG, StateType.NORMAL);
        ctx.set_line_width (3.5);
        ctx.stroke (); 
      }
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
      return Utils.markup_string_with_search (Utils.replace_home_path_with (s, "Home", " > "),
                                             get_match_search (),
                                             "medium");
    }

    /* UI INTERFACE IMPLEMENTATION */
    protected override void set_throbber_visible (bool visible)
    {
      if (visible)
        menuthrobber.active = true;
      else
        menuthrobber.active = false;
    }
    protected override void focus_match ( int index, Match? match )
    {
      string size = "x-large";
      if (match == null)
      {
        /* Show default stuff */
        if (!is_in_initial_status ())
        {
          if (is_searching_for_recent ())
          {
            match_label.set_markup (
            Markup.printf_escaped ("<span size=\"x-large\">%s</span>",
                                   TYPE_TO_SEARCH));
            match_label_description.set_markup (
              get_description_markup (menuthrobber.active ? SEARCHING : NO_RECENT_ACTIVITIES)
            );
          }
          else
          {
            match_label.set_markup (Utils.markup_string_with_search ("", get_match_search (), size));
            match_label_description.set_markup (
              get_description_markup (menuthrobber.active ? SEARCHING : NO_RESULTS)
            );
          }
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
        else
        {
          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
          match_label.set_markup (
            Markup.printf_escaped ("<span size=\"x-large\">%s</span>",
                                   TYPE_TO_SEARCH));
          match_label_description.set_markup (
            Markup.printf_escaped ("<span size=\"medium\">%s</span>",
                                   DOWN_TO_SEE_RECENT));
        }
      }
      else
      {
        match_icon.set_icon_name (match.icon_name, IconSize.DIALOG);
        if (match.has_thumbnail)
          match_icon_thumb.set_icon_name (match.thumbnail_path, IconSize.DIALOG);
        else
          match_icon_thumb.clear ();

        match_label.set_markup (Utils.markup_string_with_search (match.title, get_match_search (), size, true));
        match_label_description.set_markup (get_description_markup (match.description));
      }
      results_match.move_selection_to_index (index);
    }
    protected override void handle_empty_updated ()
    {
      if (match_label_description != null && is_in_initial_status ())
        match_label_description.set_markup (
            Markup.printf_escaped ("<span size=\"medium\">%s</span>",
                                   DOWN_TO_SEE_RECENT));
    }
    protected override void focus_action ( int index, Match? action )
    {
      string size = "x-large";
      if (action == null)
      {
        action_icon.set_sensitive (false);
        action_icon.set_icon_name ("system-run", IconSize.DIALOG);
        if (searching_for_matches)
          action_label.set_markup (Utils.markup_string_with_search (" ", "", size));
        else
          action_label.set_markup (Utils.markup_string_with_search ("", get_action_search(), size));
      }
      else
      {
        action_icon.set_sensitive (true);
        action_icon.set_icon_name (action.icon_name, IconSize.DIALOG);
        action_label.set_markup (Utils.markup_string_with_search (action.title,
                                 searching_for_matches ? 
                                 "" : get_action_search (), size));
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
