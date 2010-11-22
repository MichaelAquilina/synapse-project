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
 *
 */

using Gtk;
using Cairo;
using Gee;
using Synapse.Utils;

namespace Synapse
{
  public class SynapseWindowVirgilio : GtkCairoBase
  {
    /* Main UI shared components */
    protected VBox container = null;
    protected VBox container_for_matches = null;
    protected VBox container_for_actions = null;
    
    protected ListView<Match> list_view_matches = null;
    protected MatchRenderer list_view_matches_renderer = null;
    
    /* UI for match search */
    protected ShrinkingLabel match_search_label = null;
    private const string MATCH_SEARCH_LABEL_MARKUP = "<span size=\"x-large\"><b>%s</b></span>";
    
    private const int UI_WIDTH = 550; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 8; // assigned to containers's border width in composited
    private const int BORDER_RADIUS = 8;

    construct
    {
      window.expose_event.connect (expose_event);
      
      this.searching_for_changed.connect (visual_update_search_for);
    }

    ~SynapseWindowVirgilio ()
    {
      window.destroy ();
    }

    protected override void build_ui ()
    {
      /* Prepare colors using label */
      ColorHelper.get_default ().init_from_widget_type (typeof (Label));
      window.style_set.connect (()=>{
        ColorHelper.get_default ().init_from_widget_type (typeof (Label));
        window.queue_draw ();
      });

      /* Build the UI */
      container = new VBox (false, 5);
      container.border_width = BORDER_RADIUS;
      window.add (container);
      
      container_for_actions = new VBox (false, 0);
      container_for_actions.set_size_request (UI_WIDTH, -1);
      container_for_matches = new VBox (false, 0);
      container_for_matches.set_size_request (UI_WIDTH, -1);

      /* Building search label */
      {
        var hbox = new HBox (false, 0);
        match_search_label = new ShrinkingLabel ();
        match_search_label.xpad = 10;
        match_search_label.set_ellipsize (Pango.EllipsizeMode.END);
        match_search_label.set_alignment (0.0f, 0.5f);
        search_string_changed.connect (update_search_label);
        search_string_changed ();
        
        var searchico = new NamedIcon ();
        searchico.set_icon_name ("search", IconSize.BUTTON);
        searchico.pixel_size = 24;
        searchico.set_size_request (24, 24);
        
        hbox.pack_start (searchico, false);
        hbox.pack_start (match_search_label, true);
        hbox.set_size_request (UI_WIDTH, -1);

        container.pack_start (hbox, false);
      }
      
      container.pack_start (new HSeparator (), false);
      container.pack_start (flag_selector);
      
      /* Building Matches part */
      container_for_matches.pack_start (new HSeparator (), false);
      {
        list_view_matches_renderer = new MatchRenderer ();
        list_view_matches_renderer.icon_size = 48;
        list_view_matches_renderer.markup = "<span size=\"x-large\"><b>%s</b></span>\n<span size=\"medium\">%s</span>";
        list_view_matches_renderer.set_width_request (100);
        list_view_matches = new ListView<Match> (list_view_matches_renderer);
        list_view_matches.min_visible_rows = 5;
        list_view_matches.use_base_background = false;
        container_for_matches.pack_start (list_view_matches, false);
      }

      container.pack_start (container_for_matches, false);
      container.pack_start (container_for_actions, false);
      container.show_all ();
      visual_update_search_for ();
    }
    
    private void update_search_label ()
    {
      string s = searching_for_matches ?
                 get_match_search () :
                 get_action_search ();
      if (s.length == 0)
      {
        match_search_label.set_markup (
            Markup.printf_escaped (MATCH_SEARCH_LABEL_MARKUP, "Type to search.."));
        if (searching_for_matches && container_for_matches.visible)
        {
          container_for_matches.visible = false;
          window.queue_draw ();
        }
      }
      else
      {
        match_search_label.set_markup (
            Markup.printf_escaped (MATCH_SEARCH_LABEL_MARKUP, s));
        if (searching_for_matches && !container_for_matches.visible)
        {
          container_for_matches.visible = true;
          window.queue_draw ();
        }
      }
    }
    
    private void visual_update_search_for ()
    {
      if (searching_for_matches)
      {
        container_for_actions.hide ();
        container_for_matches.show ();
      }
      else
      {
        container_for_matches.hide ();
        container_for_actions.show ();
      }
      update_search_label ();
    }
    
    protected override void clear_search_or_hide_pressed ()
    {
      base.clear_search_or_hide_pressed ();
      //if (get_match_search () == "") set_list_visible (false);
    }
    
    protected override void on_composited_changed (Widget w)
    {
      base.on_composited_changed (w);
      if (w.is_composited ())
        window.border_width = SHADOW_SIZE;
      else
        window.border_width = 1;
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
      double x = window.border_width,
             y = window.border_width;
      double w = window.allocation.width - window.border_width * 2.0 - 1.0,
             h = window.allocation.height - window.border_width * 2.0 - 1.0;

      ctx.set_operator (Operator.OVER);
      
      // Prepare shadow color 
      double r = 0, b = 0, g = 0;
      ch.get_rgb (out r, out g, out b, ch.StyleType.BG, StateType.NORMAL, ch.Mod.INVERTED);

      if (comp)
      {
        //draw shadow
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, border_radius,
                                          r, g, b, 2.9, SHADOW_SIZE);
      }
      else
      {
        ch.set_source_rgba (ctx, 1.0, ch.StyleType.BG, StateType.NORMAL, ch.Mod.INVERTED);
        ctx.paint ();
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
        ch.set_source_rgba (ctx, 0.6, ch.StyleType.BG, StateType.NORMAL, ch.Mod.INVERTED);
        ctx.set_line_width (1.0);
        ctx.stroke ();
      }

      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
    }

    /* UI INTERFACE IMPLEMENTATION */
    protected override void focus_match ( int index, Match? match )
    {
      list_view_matches.scroll_to (index);
      list_view_matches.selected = index;
    }
    protected override void focus_action ( int index, Match? action )
    {
      
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      list_view_matches.set_list (matches);
      focus_match ( index, match );
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      //results_action.update_matches (actions);
      focus_action ( index, action );
    }
  }
}
