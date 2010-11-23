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
    private class TypeToSearchMatch : GLib.Object, Match
    {
      // for Match interface
      public string title { get; construct set; }
      public string description { get; set; default = ""; }
      public string icon_name { get; construct set; default = ""; }
      public bool has_thumbnail { get; construct set; default = false; }
      public string thumbnail_path { get; construct set; }
      public MatchType match_type { get; construct set; }

      public TypeToSearchMatch ()
      {
        GLib.Object (match_type: MatchType.ACTION,
                has_thumbnail: false);
      }
      public void set_type_to_search ()
      {
        //TODO: i18n
        title = "Type to search...";
        description = "";
        icon_name = "search";
      }
      public void set_no_results ()
      {
        //TODO: i18n
        title = "No results.";
        description = "";
        icon_name = "missing-image";
      }
    }
    /* Main UI shared components */
    protected VBox container = null;
    protected VBox container_for_matches = null;
    protected VBox container_for_actions = null;
    
    protected ListView<Match> list_view_matches = null;
    protected MatchRenderer list_view_matches_renderer = null;
    
    protected Synapse.MenuThrobber menuthrobber = null;

    private const int UI_WIDTH = 550; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 8; // assigned to containers's border width in composited
    private const int BORDER_RADIUS = 8;
    
    Gee.List<Match> tts_list;
    Gee.List<Match> nores_list;

    construct
    {
      var ttsm = new TypeToSearchMatch ();
      ttsm.set_type_to_search ();
      tts_list = new Gee.ArrayList<Match> ();
      tts_list.add (ttsm);
      
      var nores = new TypeToSearchMatch ();
      nores.set_no_results ();
      nores_list = new Gee.ArrayList<Match> ();
      nores_list.add (nores);
      
      window.expose_event.connect (expose_event);
      
      this.searching_for_changed.connect (visual_update_search_for);
      
      visual_update_search_for ();
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
        search_string_changed.connect (update_search_label);
        search_string_changed ();
        
        /* Throbber and menu */
        menuthrobber = new Synapse.MenuThrobber ();
        menu = (MenuButton) menuthrobber;
        menuthrobber.set_size_request (24, 24);
        menuthrobber.settings_clicked.connect (()=>{this.show_settings_clicked ();});
        
        hbox.pack_start (flag_selector, true);
        hbox.pack_start (menuthrobber, false);
        hbox.set_size_request (UI_WIDTH, -1);

        container.pack_start (hbox, false);
      }
      
      /* Building Matches part */
      container_for_matches.pack_start (new HSeparator (), false);
      {
        list_view_matches_renderer = new MatchRenderer ();
        list_view_matches_renderer.icon_size = 48;
        list_view_matches_renderer.markup = "<span size=\"x-large\"><b>%s</b></span>\n<span size=\"medium\">%s</span>";
        list_view_matches_renderer.set_width_request (100);
        list_view_matches_renderer.hilight_on_selected = true;
        list_view_matches_renderer.show_pattern_in_hilight = true;
        list_view_matches = new ListView<Match> (list_view_matches_renderer);
        list_view_matches.min_visible_rows = 5;
        list_view_matches.use_base_background = false;
        container_for_matches.pack_start (list_view_matches, false);
      }

      container.pack_start (container_for_matches, false);
      container.pack_start (container_for_actions, false);
      container.show_all ();
    }
    
    private void update_search_label ()
    {
      string s = searching_for_matches ?
                 get_match_search () :
                 get_action_search ();
      if (searching_for_matches && get_match_search ().length == 0)
      {
        update_match_result_list (null, 0, null);
      }
      if (list_view_matches_renderer == null) return;
      list_view_matches_renderer.pattern = s;
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
      window.queue_draw ();
      update_search_label ();
    }
    
    protected override void clear_search_or_hide_pressed ()
    {
      base.clear_search_or_hide_pressed ();
      update_search_label ();
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
    protected override void set_throbber_visible (bool visible)
    {
      if (visible)
        menuthrobber.active = true;
      else
        menuthrobber.active = false;
    }
    public override void show ()
    {
      if (window.visible) return;
      container_for_actions.hide ();
      container_for_matches.show ();
      list_view_matches.min_visible_rows = 5;
      Utils.move_window_to_center (window);
      list_view_matches.min_visible_rows = 1;
      window.show ();
    }

    protected override void focus_match ( int index, Match? match )
    {
      var matches = get_match_results ();
      if (matches == null || matches.size == 0) return;
      list_view_matches.scroll_to (index);
      list_view_matches.selected = index;
    }
    protected override void focus_action ( int index, Match? action )
    {
      
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      if (list_view_matches == null) return;
      if (matches != null && matches.size > 0)
      {
        foreach (Synapse.Match m in matches)
        {
          m.description = Utils.replace_home_path_with (m.description, "Home", " > ");
        }
        list_view_matches.set_list (matches);
        list_view_matches.min_visible_rows = 5;
        focus_match ( index, match );
      }
      else
      {
        if (get_match_search () == "")
        {
          list_view_matches.min_visible_rows = 1;
          list_view_matches.set_list (tts_list);
        }
        else
        {
          list_view_matches.min_visible_rows = 5;
          list_view_matches.set_list (nores_list);
        }

        list_view_matches.scroll_to (0);
        list_view_matches.selected = -1;
      }
      window.queue_draw ();
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      //results_action.update_matches (actions);
      focus_action ( index, action );
    }
  }
}
