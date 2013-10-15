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
using Gtk;
using Cairo;

namespace Synapse.Gui
{
  public class ViewVirgilio : Synapse.Gui.View
  {
    construct {
      
    }
    
    static construct {
      /* Override here style properties */
      var icon_size = new GLib.ParamSpecInt ("icon-size",
                                             "Icon Size",
                                             "The size of focused icon in supported themes",
                                             24, 64, 48,
                                             GLib.ParamFlags.READWRITE);
      var title_max = new GLib.ParamSpecString ("title-size",
                                                "Title Font Size",
                                                "The standard size the match title in Pango absolute sizes (string)",
                                                "large",
                                                GLib.ParamFlags.READWRITE);
      
      var descr_max = new GLib.ParamSpecString ("description-size",
                                                "Description Font Size",
                                                "The standard size the match description in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READWRITE);

      install_style_property (icon_size);
      install_style_property (title_max);
      install_style_property (descr_max);
    }
    
    public override void style_updated ()
    {
      base.style_updated ();

      int width, icon_size;
      string tmax, dmax;
      style_get ("ui-width", out width, "icon-size", out icon_size,
        "title-size", out tmax, "description-size", out dmax);

      container.set_size_request (width, -1);
      fix_listview_size (results_sources.get_match_renderer (), icon_size, tmax, dmax);
      fix_listview_size (results_actions.get_match_renderer (), icon_size, tmax, dmax);
      fix_listview_size (results_targets.get_match_renderer (), icon_size, tmax, dmax);
    }

    private Box container;
    private Box action_box;
    private Box target_box;
    
    private SmartLabel status;
    private SmartLabel logo;
    private SmartLabel search;
    
    private SpecificMatchList results_sources;
    private SpecificMatchList results_actions;
    private SpecificMatchList results_targets;
    
    private MenuThrobber menuthrobber;
    
    protected override void build_ui ()
    {
      container = new Box (Gtk.Orientation.VERTICAL, 0);
      
      status = new SmartLabel ();
      logo = new SmartLabel ();
      search = new SmartLabel ();
      search.set_animation_enabled (true);
      search.xalign = 0.5f;
      logo.xalign = 1.0f;
      status.xalign = 0.0f;
      logo.set_markup (Markup.printf_escaped ("<i>%s</i>", Config.RELEASE_NAME));
      var hb_status = new Box (Gtk.Orientation.HORIZONTAL, 0);
      hb_status.homogeneous = true;
      hb_status.pack_start (status);
      hb_status.pack_start (search);
      hb_status.pack_start (logo);
      
      /* Categories - Throbber and menu */
      var categories_hbox = new Box (Gtk.Orientation.HORIZONTAL, 0);

      menuthrobber = new MenuThrobber ();
      menu = (MenuButton) menuthrobber;
      menuthrobber.set_size_request (14, 14);

      categories_hbox.pack_start (flag_selector);
      categories_hbox.pack_start (menuthrobber, false);
      
      container.pack_start (categories_hbox, false, false, 2);
      container.pack_start (create_separator (), false);
      
      /* Sources */
      results_sources = new SpecificMatchList (controller, model, SearchingFor.SOURCES);
      results_actions = new SpecificMatchList (controller, model, SearchingFor.ACTIONS);
      results_targets = new SpecificMatchList (controller, model, SearchingFor.TARGETS);
      results_sources.use_base_colors = false;
      results_actions.use_base_colors = false;
      results_targets.use_base_colors = false;
      fix_listview_size (results_sources.get_match_renderer ());
      fix_listview_size (results_actions.get_match_renderer ());
      fix_listview_size (results_targets.get_match_renderer ());

      container.pack_start (results_sources);
      container.pack_start (create_separator (), false);
      
      action_box = new Box (Gtk.Orientation.VERTICAL, 0);
      action_box.pack_start (results_actions, false);
      action_box.pack_start (create_separator (), false);
      container.pack_start (action_box, false);
      
      target_box = new Box (Gtk.Orientation.VERTICAL, 0);
      target_box.pack_start (results_targets, false);
      target_box.pack_start (create_separator (), false);
      container.pack_start (target_box, false);
      
      container.pack_start (hb_status, false, false, 2);

      container.show_all ();

      container.set_size_request (500, -1);
      this.add (container);
    }

    //FIXME GtkSeparators won't show up. Here we have a workaround
    private Gtk.Widget create_separator ()
    {
      var separator = new Gtk.EventBox ();
      separator.height_request = 2;
      separator.width_request = 120;
      separator.get_style_context ().add_class (Gtk.STYLE_CLASS_SEPARATOR);
      separator.get_style_context ().add_class (Gtk.STYLE_CLASS_HORIZONTAL);
      separator.draw.connect (draw_separator);
      return separator;
    }

    private bool draw_separator (Gtk.Widget separator, Cairo.Context ctx)
    {
      separator.get_style_context ().render_frame (ctx, 0, 0, separator.get_allocated_width (), 2);
      return false;
    }
    
    private void fix_listview_size (MatchViewRenderer rend, int iconsize = 48, string title = "large", string desc = "medium")
    {
      rend.icon_size = iconsize;
      rend.title_markup = "<span size=\"%s\"><b>%%s</b></span>".printf (title);
      rend.description_markup = "<span size=\"%s\">%%s</span>".printf (desc);
    }
    
    public override bool is_list_visible ()
    {
      return true;
    }
    
    public override void set_list_visible (bool visible)
    {
      if (this.visible) return;
      results_sources.min_visible_rows = visible ? 7 : 1;
    }
    
    public override void set_throbber_visible (bool visible)
    {
      menuthrobber.active = visible;
    }
    
    public override void update_searching_for ()
    {
      results_sources.update_searching_for ();
      results_actions.update_searching_for ();
      results_targets.update_searching_for ();
      target_box.visible = results_targets.min_visible_rows > 0;
      update_labels ();
    }
    
    private void update_labels ()
    {
      if (model.has_results ())
      {
        status.set_markup (Markup.printf_escaped (_("<b>%d of %d</b>"), model.get_actual_focus().key+1, model.results[model.searching_for].size));
      }
      else
      {
        status.set_text ("");
      }
      search.set_text (model.query[model.searching_for]);
    }
    
    public override void update_selected_category ()
    {
      flag_selector.selected = model.selected_category;
    }
    
    protected override void paint_background (Cairo.Context ctx)
    {
      Gtk.Allocation container_allocation;
      container.get_allocation (out container_allocation);
      
      int width = container_allocation.width + BORDER_RADIUS * 2;
      int height = container_allocation.height + BORDER_RADIUS * 2;
      ctx.translate (container_allocation.x - BORDER_RADIUS, container_allocation.y - BORDER_RADIUS);
      if (this.is_composited ())
      {
        ctx.translate (0.5, 0.5);
        ctx.set_operator (Operator.OVER);
        Utils.cairo_make_shadow_for_rect (ctx, 0, 0, width - 1, height - 1,
                                               BORDER_RADIUS, 0, 0, 0, SHADOW_SIZE);
        ctx.translate (-0.5, -0.5);
      }
      ctx.save ();
      // pattern
      Pattern pat = new Pattern.linear(0, 0, 0, height);
      ch.add_color_stop_rgba (pat, 0.0, 0.95, StyleType.BG, StateFlags.NORMAL, Mod.LIGHTER);
      ch.add_color_stop_rgba (pat, 0.2, 1.0, StyleType.BG, StateFlags.NORMAL, Mod.NORMAL);
      ch.add_color_stop_rgba (pat, 1.0, 1.0, StyleType.BG, StateFlags.NORMAL, Mod.DARKER);
      Utils.cairo_rounded_rect (ctx, 0, 0, width, height, BORDER_RADIUS);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
    }
    
    public override void update_focused_source (Entry<int, Match> m)
    {
      if (m.value != null) results_sources.set_indexes (m.key, m.key);
      if (model.searching_for == SearchingFor.SOURCES) update_labels ();
    }
    
    public override void update_focused_action (Entry<int, Match> m)
    {
      if (m.value != null)
      {
        results_actions.set_indexes (m.key, m.key);
      }
      if (model.searching_for == SearchingFor.ACTIONS) update_labels ();
    }
    
    public override void update_focused_target (Entry<int, Match> m)
    {
      if (m.value != null) results_targets.set_indexes (m.key, m.key);
      if (model.searching_for == SearchingFor.TARGETS) update_labels ();
    }
    
    public override void update_sources (Gee.List<Match>? list = null)
    {
      results_sources.set_list (list);
      action_box.visible = !controller.is_in_initial_state ();
    }
    public override void update_actions (Gee.List<Match>? list = null)
    {
      results_actions.set_list (list);
    }
    public override void update_targets (Gee.List<Match>? list = null)
    {
      results_targets.set_list (list);
      results_targets.update_searching_for ();
      target_box.visible = results_targets.min_visible_rows > 0;
    }
  }
}
