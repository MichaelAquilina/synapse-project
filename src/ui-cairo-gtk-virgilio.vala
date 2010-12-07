/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
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

using Gtk;
using Cairo;
using Gee;
using Synapse.Gui.Utils;

namespace Synapse.Gui
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
        title = TYPE_TO_SEARCH;
        description = "";
        icon_name = "search";
      }
      public void set_no_results ()
      {
        title = NO_RESULTS;
        description = "";
        icon_name = "missing-image";
      }
    }
    /* Main UI shared components */
    protected VBox container = null;
    protected VBox container_for_matches = null;
    protected VBox container_for_actions = null;
    protected ShrinkingLabel search_label = null;
    protected Label actions_status_label = null;
    protected Label matches_status_label = null;
    protected HSelectionContainer status_selector = null;
    protected Label codename_label = null;
    
    protected ListView<Match> list_view_matches = null;
    protected MatchRenderer list_view_matches_renderer = null;
    protected NamedIcon thumb_icon = null;
    
    private TypeToSearchMatch tts;

    protected ListView<Match> list_view_actions = null;
    protected MatchRenderer list_view_actions_renderer = null;
    
    protected MenuThrobber menuthrobber = null;

    private const int UI_WIDTH = 550; // height is dynamic
    private const int PADDING = 8; // assinged to container_top's border width
    private const int SHADOW_SIZE = 8; // assigned to containers's border width in composited
    private const int BORDER_RADIUS = 8;
    private const int THUMB_SIZE = 140;
    
    Gee.List<Match> tts_list;
    Gee.List<Match> nores_list;

    construct
    {
      window.expose_event.connect (expose_event);
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
      container = new VBox (false, 4);
      container.border_width = BORDER_RADIUS;
      window.add (container);
      
      container_for_actions = new VBox (false, 0);
      container_for_actions.set_size_request (UI_WIDTH, -1);
      container_for_matches = new VBox (false, 0);
      container_for_matches.set_size_request (UI_WIDTH, -1);
      
      search_label = new ShrinkingLabel ();
      search_label.set_alignment (0.5f, 0.5f);
      search_label.set_ellipsize (Pango.EllipsizeMode.START);
      
      codename_label = new Label (null);
      codename_label.set_markup (Markup.printf_escaped ("<i>%s</i>", Config.RELEASE_NAME));
      codename_label.set_alignment (1.0f, 0.5f);
      
      actions_status_label = new Label (null);
      matches_status_label = new Label (null);
      actions_status_label.set_alignment (0.0f, 0.5f);
      matches_status_label.set_alignment (0.0f, 0.5f);
      
      status_selector = new HSelectionContainer (null, 0);
      status_selector.add (matches_status_label);
      status_selector.add (actions_status_label);
      status_selector.set_separator_visible (false);

      /* Building search label */
      {
        var hbox = new HBox (false, 0);
        
        /* Throbber and menu */
        menuthrobber = new MenuThrobber ();
        menu = (MenuButton) menuthrobber;
        menuthrobber.set_size_request (24, 24);
        menuthrobber.settings_clicked.connect (()=>{this.show_settings_clicked ();});
        
        var left_spacer = new Label (null);
        left_spacer.set_size_request (24, 24);
        
        hbox.pack_start (left_spacer, false);
        hbox.pack_start (flag_selector, true);
        hbox.pack_start (menuthrobber, false);
        hbox.set_size_request (UI_WIDTH, -1);

        container.pack_start (hbox, false);
        hbox = new HBox (true, 5);
        hbox.pack_start (status_selector, true, false);
        hbox.pack_start (search_label);
        hbox.pack_start (codename_label, true, false);
        container.pack_end (hbox);
        container.pack_end (new HSeparator (), false);
      }
      
      /* Building Matches part */
      container_for_matches.pack_start (new HSeparator (), false);
      {
        list_view_matches_renderer = new MatchRenderer ();
        list_view_matches_renderer.icon_size = 48;
        list_view_matches_renderer.cell_vpadding = 1;
        list_view_matches_renderer.title_markup = "<span size=\"large\"><b>%s</b></span>";
        list_view_matches_renderer.description_markup = "<span size=\"medium\">%s</span>";
        list_view_matches_renderer.set_width_request (100);
        list_view_matches_renderer.hilight_on_selected = true;
        list_view_matches_renderer.hide_extended_on_selected = true;
        list_view_matches = new ListView<Match> (list_view_matches_renderer);
        list_view_matches.min_visible_rows = 5;
        list_view_matches.use_base_background = false;
        container_for_matches.pack_start (list_view_matches, false);
      }

      container.pack_start (container_for_matches, false);

      {
        list_view_actions_renderer = new MatchRenderer ();
        list_view_actions_renderer.icon_size = 36;
        list_view_actions_renderer.cell_vpadding = 1;
        list_view_actions_renderer.title_markup = "<span size=\"medium\"><b>%s</b></span>";
        list_view_actions_renderer.description_markup = "<span size=\"small\">%s</span>";
        list_view_actions_renderer.set_width_request (100);
        list_view_actions_renderer.hilight_on_selected = true;
        list_view_actions_renderer.show_extended_info = false;
        list_view_actions = new ListView<Match> (list_view_actions_renderer);
        list_view_actions.min_visible_rows = 5;
        list_view_actions.use_base_background = false;

        thumb_icon = new NamedIcon ();
        thumb_icon.set_pixel_size (THUMB_SIZE);
        thumb_icon.set_size_request (THUMB_SIZE, THUMB_SIZE);
        var hbox = new HBox (false, 5);
        hbox.pack_start (list_view_actions);
        hbox.pack_start (thumb_icon, false);

        container_for_actions.pack_start (new HSeparator (), false);
	      container_for_actions.pack_start (hbox, false);
      }
      container.pack_start (container_for_actions, false);
      container.show_all ();
      
      tts = new TypeToSearchMatch ();
      tts.set_type_to_search ();
      tts.description = DOWN_TO_SEE_RECENT;
      tts_list = new Gee.ArrayList<Match> ();
      tts_list.add (tts);
      
      var nores = new TypeToSearchMatch ();
      nores.set_no_results ();
      nores_list = new Gee.ArrayList<Match> ();
      nores_list.add (nores);
      
      this.searching_for_changed.connect (visual_update_search_for);
      
      visual_update_search_for ();
      
      search_string_changed.connect (update_search_label);
      
      reset_search ();
    }
    
    protected override void handle_empty_updated ()
    {
      tts = new TypeToSearchMatch ();
      tts.set_type_to_search ();
      tts.description = DOWN_TO_SEE_RECENT;
      tts_list = new Gee.ArrayList<Match> ();
      tts_list.add (tts);
      if (list_view_matches != null && is_in_initial_status ()) list_view_matches.set_list (tts_list);
    }
    
    private void update_search_label ()
    {
      string s = searching_for_matches ?
                 get_match_search () :
                 get_action_search ();
      if (s == "" || s == null)
        s = "...";
      search_label.set_markup (Markup.printf_escaped ("<span size=\"medium\"><b>%s </b></span>", s));
    }
    
    private void visual_update_search_for ()
    {
      if (searching_for_matches)
      {
        container_for_actions.hide ();
        list_view_matches.scroll_mode = ListView.ScrollMode.MIDDLE;
        list_view_matches.set_inhibit_focus (false);
        if (is_in_initial_status ())
          list_view_matches.min_visible_rows = 1;
        else
          list_view_matches.min_visible_rows = 5;
      }
      else
      {
        container_for_actions.show ();
        list_view_matches.set_inhibit_focus (true);
        list_view_matches.scroll_mode = ListView.ScrollMode.TOP_FORCED;
        list_view_matches.min_visible_rows = 1;
      }
      status_selector.select (searching_for_matches ? 0 : 1);
      update_search_label ();
      window.queue_draw ();
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
                                          r, g, b, 0.9, SHADOW_SIZE);
      }
      else
      {
        ch.set_source_rgba (ctx, 1.0, ch.StyleType.BG, StateType.NORMAL, ch.Mod.INVERTED);
        ctx.paint ();
      }
      ctx.set_operator (Operator.SOURCE);
      Pattern pat = new Pattern.linear(0, y, 0, y + h);
      ch.add_color_stop_rgba (pat, 0, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.LIGHTER);
      ch.add_color_stop_rgba (pat, 0.85, 0.97, ch.StyleType.BG, StateType.NORMAL, ch.Mod.NORMAL);
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
      update_match_result_list (null, 0, null);
      update_search_label ();
      window.show ();
    }

    protected override void focus_match ( int index, Match? match )
    {
      var matches = get_match_results ();
      if (matches == null || matches.size == 0) {list_view_matches_renderer.pattern = ""; return;}
      list_view_matches_renderer.pattern = get_match_search ();
      list_view_matches.scroll_to (index);
      list_view_matches.selected = index;
      if (searching_for_matches)
        matches_status_label.set_markup (Markup.printf_escaped (_("<b>%d of %d</b>"), index + 1, matches.size));
      if (match.has_thumbnail)
      {
        thumb_icon.set_icon_name (match.thumbnail_path, IconSize.DIALOG);
        thumb_icon.show ();
      }
      else
      {
        thumb_icon.hide ();
      }
    }
    protected override void focus_action ( int index, Match? action )
    {
      var actions = get_action_results ();
      if (actions == null || actions.size == 0) {list_view_actions_renderer.pattern = ""; list_view_matches_renderer.action = null; return;}
      list_view_matches_renderer.action = action;
      list_view_actions_renderer.pattern = get_action_search ();
      list_view_actions.scroll_to (index);
      list_view_actions.selected = index;
      if (!searching_for_matches)
        actions_status_label.set_markup (Markup.printf_escaped (_("<b>%d of %d</b>"), index + 1, actions.size));

    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      if (list_view_matches == null) return;
      if (matches != null && matches.size > 0)
      {
        foreach (Match m in matches)
        {
          m.description = Utils.replace_home_path_with (m.description, _("Home"), " > ");
        }
        list_view_matches.set_list (matches);
        list_view_matches.min_visible_rows = 5;
        list_view_matches.set_inhibit_focus (false);
        matches_status_label.set_markup (Markup.printf_escaped (_("<b>1 of %d</b>"), matches.size));
        focus_match ( index, match );
      }
      else
      {
        matches_status_label.set_markup ("");
        if (get_match_search () == "" && matches == null)
        {
          list_view_matches.min_visible_rows = 1;
          list_view_matches.set_list (tts_list);
          list_view_matches.set_inhibit_focus (true);
        }
        else
        {
          list_view_matches.min_visible_rows = 5;
          list_view_matches.set_list (nores_list);
          list_view_matches.set_inhibit_focus (true);
          list_view_matches_renderer.action = null;
        }

        list_view_matches.scroll_to (0);
        list_view_matches.selected = 0;
        focus_match ( 0, null );
      }
      window.queue_draw ();
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      if (list_view_actions == null) return;
      if (actions != null && actions.size > 0)
      {
        list_view_actions.set_list (actions);
        actions_status_label.set_markup (Markup.printf_escaped (_("<b>1 of %d</b>"), actions.size));
        focus_action ( index, action );
      }
      else
      {
        actions_status_label.set_markup ("");
        if (get_action_search () == "")
        {
          list_view_actions.set_list (tts_list);
        }
        else
        {
          list_view_actions.set_list (nores_list);
        }

        list_view_actions.scroll_to (0);
        list_view_actions.selected = -1;
      }
      window.queue_draw ();
    }
  }
}
