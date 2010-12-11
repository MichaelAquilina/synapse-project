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
  public class SynapseWindowMini : GtkCairoBase
  {
    /* Main UI shared components */
    protected NamedIcon match_icon = null;
    protected NamedIcon match_icon_thumb = null;
    protected NamedIcon action_icon = null;
    protected ContainerOverlayed match_icon_container_overlayed = null;
    
    protected Label match_label_description = null;
    protected ShrinkingLabel current_label = null;

    protected HBox container_top = null;
    protected VBox container = null;
    
    protected HSelectionContainer results_container = null;

    protected ResultBox results_match = null;
    protected ResultBox results_action = null;

    private const int UI_WIDTH = 620; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SECTION_PADDING = 10;
    private const int BORDER_RADIUS = 10;
    private const int ICON_SIZE = 160;
    private const int TOP_SPACING = ICON_SIZE / 2;
    private const int LABEL_INTERNAL_PADDING = 4;
    private const string LABEL_TEXT_SIZE = "x-large";

    /* STATUS */
    private bool list_visible = true;
    
    construct
    {
      window.expose_event.connect (expose_event);
      
      this.searching_for_changed.connect (visual_update_search_for);

      set_list_visible (false);
    }

    ~SynapseWindowMini ()
    {
      window.destroy ();
    }

    protected override void build_ui ()
    {
      /* containers holds top hbox and result list */
      container = new VBox (false, 0);
      container.border_width = SHADOW_SIZE;
      window.add (container);
      
      container_top = new HBox (false, 0);
      container_top.border_width = BORDER_RADIUS;
      container_top.set_size_request (UI_WIDTH, -1);
      container.pack_start (container_top, false);
      
      results_container = new HSelectionContainer (null, 0);
      results_container.set_separator_visible (false);
      container.pack_start (results_container, false);
      
      results_match = new ResultBox (UI_WIDTH - 2);
      results_action = new ResultBox (UI_WIDTH - 2);
      results_container.add (results_match);
      results_container.add (results_action);

      /* Action Icon */
      action_icon = new NamedIcon ();
      action_icon.set_pixel_size (ICON_SIZE * 29 / 100);
      action_icon.set_alignment (0.5f, 0.5f);
      /* Match Icon packed into container_top */
      match_icon_container_overlayed = new ContainerOverlayed();
      match_icon_thumb = new NamedIcon();
      match_icon_thumb.set_pixel_size (ICON_SIZE / 2);
      match_icon = new NamedIcon ();
      match_icon.set_pixel_size (ICON_SIZE);
      match_icon_container_overlayed.set_size_request (ICON_SIZE, ICON_SIZE);
      match_icon_container_overlayed.set_scale_for_pos (0.3f, ContainerOverlayed.Position.BOTTOM_RIGHT);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon, ContainerOverlayed.Position.MAIN);
      match_icon_container_overlayed.set_widget_in_position 
            (match_icon_thumb, ContainerOverlayed.Position.BOTTOM_LEFT);
      match_icon_container_overlayed.set_widget_in_position 
            (action_icon, ContainerOverlayed.Position.BOTTOM_RIGHT);
      container_top.pack_start (match_icon_container_overlayed, false);
      
      throbber = new Throbber ();
      throbber.set_size_request (18, 18);
      
      /* Match or Action Label */
      current_label = new ShrinkingLabel ();
      current_label.xpad = LABEL_INTERNAL_PADDING;
      current_label.set_alignment (0.0f, 1.0f);
      current_label.set_ellipsize (Pango.EllipsizeMode.END);
      var fakeinput = new FakeInput ();
      fakeinput.border_radius = 5;
      {
        var hbox = new HBox (false, 0);
        hbox.border_width = LABEL_INTERNAL_PADDING;
        hbox.pack_start (current_label);
        hbox.pack_start (throbber, false, false);
        hbox.pack_start (new Label ("  "), false, false);
        fakeinput.add (hbox);
      }

      /* Menu item */
      menu = new MenuButton ();
      menu.settings_clicked.connect (()=>{this.show_settings_clicked ();});
      menu.button_scale = 1.0;
      menu.set_size_request (10, 20);
      {
        var vbox = new VBox (false, 0);
        var spacer = new Label (null);
        spacer.set_size_request (-1, TOP_SPACING);
        vbox.pack_start (spacer, false);
        vbox.pack_start (flag_selector, false);
        vbox.pack_start (new HSeparator (), false);
        vbox.pack_start (fakeinput, false);
        vbox.pack_start (new Label(null));
        container_top.pack_start (vbox);
      }
      {
        var vbox = new VBox (false, 0);
        var spacer = new Label (null);
        spacer.set_size_request (-1, TOP_SPACING);
        vbox.pack_start (spacer, false);
        vbox.pack_start (menu, false);
        container_top.pack_start (vbox, false);
      }
      
      container.show_all ();
    }
    
    protected override bool show_list (bool visible)
    {
      if (list_visible == visible) return false;
      set_list_visible (visible);
      return true;
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
    
    protected override void on_composited_changed (Widget w)
    {
      base.on_composited_changed (w);
      if (w.is_composited ())
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
      double border_radius = comp ? BORDER_RADIUS : 0;
      double x = this.container.border_width,
             y = flag_selector.allocation.y - border_radius;
      double w = UI_WIDTH - 1.0,
             h = current_label.allocation.y - y + current_label.allocation.height + border_radius - 1.0;
      if (!comp)
      {
        y = this.container.border_width;
        h = container_top.allocation.height;
      }
      ctx.set_operator (Operator.OVER);
      
      /* Prepare shadow color */
      double r = 0, b = 0, g = 0;

      if (list_visible)
      {
        double ly = y + h - border_radius;
        double lh = results_container.allocation.y - ly + results_container.allocation.height;
        ctx.rectangle (x, ly, w, lh);
        /* draw background for the result list */
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
        ctx.set_operator (Operator.OVER);
        Utils.cairo_rounded_rect (ctx, x, y, w, h, border_radius);
        ctx.set_source_rgba (r, g, b, 0.6);
        ctx.set_line_width (1.0);
        ctx.stroke ();
      }

      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
    }
    
    protected override void set_input_mask ()
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
               h = current_label.allocation.y - y + current_label.allocation.height + BORDER_RADIUS;
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

    private void visual_update_search_for ()
    {
      if (searching_for_matches)
      {
        action_icon.set_pixel_size (ICON_SIZE * 29 / 100);
        match_icon.set_pixel_size (ICON_SIZE);
        match_icon_container_overlayed.swapif (action_icon,
                                               ContainerOverlayed.Position.MAIN,
                                               ContainerOverlayed.Position.BOTTOM_RIGHT);
        results_container.select (0);
      }
      else
      {
        match_icon.set_pixel_size (ICON_SIZE * 29 / 100);
        action_icon.set_pixel_size (ICON_SIZE);
        match_icon_container_overlayed.swapif (match_icon,
                                               ContainerOverlayed.Position.MAIN,
                                               ContainerOverlayed.Position.BOTTOM_RIGHT);
        results_container.select (1);
      }
    }

    /* UI INTERFACE IMPLEMENTATION */
    protected override void focus_match ( int index, Match? match )
    {
      if (match == null)
      {
        /* Show default stuff */
        if (get_match_search () != "")
        {
          if (searching_for_matches)
           current_label.set_markup (Utils.markup_string_with_search ("", get_match_search (), LABEL_TEXT_SIZE));

          match_icon.set_icon_name ("search", IconSize.DIALOG);
          match_icon_thumb.clear ();
        }
        else
        {
          if (searching_for_matches)
            current_label.set_markup (
            Markup.printf_escaped ("<span size=\"%s\">%s</span>", LABEL_TEXT_SIZE,
                                   TYPE_TO_SEARCH));
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
          current_label.set_markup (Utils.markup_string_with_search (match.title, get_match_search (), LABEL_TEXT_SIZE, true));
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
          current_label.set_markup (Utils.markup_string_with_search ("", get_action_search(), LABEL_TEXT_SIZE));
      }
      else
      {
        action_icon.show ();
        action_icon.set_icon_name (action.icon_name, IconSize.DIALOG);
        if (!searching_for_matches)
          current_label.set_markup (Utils.markup_string_with_search (action.title, get_action_search (), LABEL_TEXT_SIZE, true));
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
