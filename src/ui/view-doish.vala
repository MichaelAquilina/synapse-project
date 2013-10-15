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
  public class ViewDoish : Synapse.Gui.View
  {
    construct {
      
    }
    
    static construct
    {
      /* Override here style properties */
      var icon_size = new GLib.ParamSpecInt ("icon-size",
                                             "Icon Size",
                                             "The size of focused icon in supported themes",
                                             32, 256, 128,
                                             GLib.ParamFlags.READWRITE);
      var title_max = new GLib.ParamSpecString ("title-size",
                                                "Title Font Size",
                                                "The standard size the match title in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READWRITE);
      var title_min = new GLib.ParamSpecString ("title-min-size",
                                                "Title minimum Font Size",
                                                "The minimum size the match title in Pango absolute sizes (string)",
                                                "small",
                                                GLib.ParamFlags.READWRITE);
      var descr_max = new GLib.ParamSpecString ("description-size",
                                                "Description Font Size",
                                                "The standard size the match description in Pango absolute sizes (string)",
                                                "small",
                                                GLib.ParamFlags.READWRITE);
      var descr_min = new GLib.ParamSpecString ("description-min-size",
                                                "Description minimum Font Size",
                                                "The minimum size the match description in Pango absolute sizes (string)",
                                                "small",
                                                GLib.ParamFlags.READWRITE);
      install_style_property (icon_size);
      install_style_property (title_max);
      install_style_property (title_min);
      install_style_property (descr_max);
      install_style_property (descr_min);
    }
    
    public override void style_updated ()
    {
      base.style_updated ();

      int spacing, icon_size;
      string tmax, tmin, dmax, dmin;
	  style_get ("pane-spacing", out spacing, "icon-size", out icon_size,
        "title-size", out tmax, "title-min-size", out tmin, "description-size", out dmax,
        "description-min-size", out dmin);
      
      sp1.set_size_request (spacing, -1);
      sp2.set_size_request (spacing, -1);

      source_icon.set_pixel_size (icon_size);
      action_icon.set_pixel_size (icon_size);
      target_icon.set_pixel_size (icon_size);
      spacer.set_size_request (1, SHADOW_SIZE + BORDER_RADIUS);
      source_label.size = SmartLabel.string_to_size (tmax);
      source_label.min_size = SmartLabel.string_to_size (tmin);
      action_label.size = SmartLabel.string_to_size (tmax);
      action_label.min_size = SmartLabel.string_to_size (tmin);
      target_label.size = SmartLabel.string_to_size (tmax);
      target_label.min_size = SmartLabel.string_to_size (tmin);
      description_label.size = SmartLabel.string_to_size (dmax);
      description_label.min_size = SmartLabel.string_to_size (dmin);
    }
    
    private NamedIcon source_icon;
    private NamedIcon action_icon;
    private NamedIcon target_icon;
    
    private SmartLabel source_label;
    private SmartLabel action_label;
    private SmartLabel target_label;
    private SmartLabel description_label;
    
    private SelectionContainer results_container;
    
    private ResultBox results_sources;
    private ResultBox results_actions;
    private ResultBox results_targets;
    
    private MenuThrobber menuthrobber;
    
    private Box target_container;
    private Box container;
    
    private Box spane; //source and action panes
    private Box apane;
    private Box tpane;
    
    private Label sp1;
    private Label sp2;
    
    protected override void build_ui ()
    {
      /* Icons */
      source_icon = new NamedIcon ();
      action_icon = new NamedIcon ();
      target_icon = new NamedIcon ();
      source_icon.set_icon_name ("search", IconSize.DND);
      action_icon.clear ();
      target_icon.set_icon_name ("");
      
      source_icon.set_pixel_size (128);
      source_icon.xpad = 15;
      action_icon.set_pixel_size (128);
      action_icon.xpad = 15;
      target_icon.set_pixel_size (128);
      target_icon.xpad = 15;
      
      /* Labels */
      source_label = new SmartLabel ();
      source_label.set_ellipsize (Pango.EllipsizeMode.END);
      source_label.size = SmartLabel.Size.MEDIUM;
      source_label.min_size = SmartLabel.Size.SMALL;
      source_label.set_state_flags (StateFlags.SELECTED, false);
      source_label.xalign = 0.5f;
      action_label = new SmartLabel ();
      action_label.set_ellipsize (Pango.EllipsizeMode.END);
      action_label.size = SmartLabel.Size.MEDIUM;
      action_label.min_size = SmartLabel.Size.SMALL;
      action_label.set_state_flags (StateFlags.SELECTED, false);
      action_label.xalign = 0.5f;
      target_label = new SmartLabel ();
      target_label.set_ellipsize (Pango.EllipsizeMode.END);
      target_label.size = SmartLabel.Size.MEDIUM;
      target_label.min_size = SmartLabel.Size.SMALL;
      target_label.set_state_flags (StateFlags.SELECTED, false);
      target_label.xalign = 0.5f;
      description_label = new SmartLabel ();
      description_label.size = SmartLabel.Size.SMALL;
      description_label.set_animation_enabled (true);
      description_label.set_state_flags (StateFlags.SELECTED, false);
      description_label.xalign = 0.5f;
      
      /* Categories - Throbber and menu */ //#0C71D6
      var categories_hbox = new Box (Gtk.Orientation.HORIZONTAL, 0);

      menuthrobber = new MenuThrobber ();
      menuthrobber.set_state_flags (StateFlags.SELECTED, false);
      menu = (MenuButton) menuthrobber;
      menuthrobber.set_size_request (14, 14);

      categories_hbox.pack_start (flag_selector);
      categories_hbox.pack_start (menuthrobber, false);

      flag_selector.selected_markup = "<span size=\"small\"><b>%s</b></span>";
      flag_selector.unselected_markup = "<span size=\"x-small\">%s</span>";
      flag_selector.set_state_flags (StateFlags.SELECTED, false);

      var hbox_panes = new Box (Gtk.Orientation.HORIZONTAL, 0);

      /* PANES */
      sp1 = new Label (null);
      sp2 = new Label (null);

      /* Source Pane */
      spane = new Box (Gtk.Orientation.VERTICAL, 0);
      spane.border_width = 5;
      var sensitive = new SensitiveWidget (source_icon);
      this.make_draggable (sensitive);
      spane.pack_start (sensitive, false);
      spane.pack_start (source_label, false);
      
      /* Action Pane */
      apane = new Box (Gtk.Orientation.VERTICAL, 0);
      apane.border_width = 5;
      apane.pack_start (action_icon, false);
      apane.pack_start (action_label, false);
      
      hbox_panes.pack_start (spane, false);
      hbox_panes.pack_start (sp1, true);
      hbox_panes.pack_start (apane, true);

      /* Target Pane */
      tpane = new Box (Gtk.Orientation.VERTICAL, 0);
      tpane.border_width = 5;
      sensitive = new SensitiveWidget (target_icon);
      this.make_draggable (sensitive);
      tpane.pack_start (sensitive, false);
      tpane.pack_start (target_label, false);
      
      target_container = new Box (Gtk.Orientation.VERTICAL, 0);
      var hb = new Box (Gtk.Orientation.HORIZONTAL, 0);
      hb.pack_start (sp2, false);
      hb.pack_start (tpane, false, false);
      target_container.pack_start (new CloneWidget (categories_hbox), false);
      target_container.pack_start (hb, false, true, 5);
      target_container.pack_start (new Label (null), true);

      /* list */
      this.prepare_results_container (out results_container, out results_sources,
                                      out results_actions, out results_targets, StateFlags.SELECTED);

      container = new Box (Gtk.Orientation.VERTICAL, 0);
      container.pack_start (categories_hbox, false);
      container.pack_start (hbox_panes, false, true, 5);
      container.pack_start (description_label, false);
      container.pack_start (spacer, false);
      container.pack_start (results_container, false);
      
      var main_container = new Box (Gtk.Orientation.HORIZONTAL, 0);
      main_container.pack_start (container, false);
      main_container.pack_start (target_container, false);
      
      main_container.show_all ();
      results_container.hide ();
      
      this.add (main_container);
    }
    
    public override bool is_list_visible ()
    {
      return results_container.visible;
    }
    
    public override void set_list_visible (bool visible)
    {
      results_container.visible = visible;
    }
    
    public override void set_throbber_visible (bool visible)
    {
      menuthrobber.active = visible;
    }
    
    public override void update_searching_for ()
    {
      update_labels ();
      results_container.select_child (model.searching_for);
      queue_draw ();
    }
    
    public override void update_selected_category ()
    {
      flag_selector.selected = model.selected_category;
    }
    
    protected override void paint_background (Cairo.Context ctx)
    {
      bool comp = this.is_composited ();
      double r = 0, b = 0, g = 0;

      Gtk.Allocation spacer_allocation, flag_selector_allocation,
        spane_allocation, apane_allocation;
      spacer.get_allocation (out spacer_allocation);
      flag_selector.get_allocation (out flag_selector_allocation);
      spane.get_allocation (out spane_allocation);
      apane.get_allocation (out apane_allocation);

      if (is_list_visible () || (!comp))
      {
        if (comp && is_list_visible ())
        {
          Gtk.Allocation results_container_allocation;
          results_container.get_allocation (out results_container_allocation);
          ctx.translate (0.5, 0.5);
          ctx.set_operator (Operator.OVER);
          Utils.cairo_make_shadow_for_rect (ctx, results_container_allocation.x,
                                                 results_container_allocation.y,
                                                 results_container_allocation.width - 1,
                                                 results_container_allocation.height - 1,
                                                 0, r, g, b, SHADOW_SIZE);
          ctx.translate (-0.5, -0.5);
        }
        ctx.set_operator (Operator.SOURCE);
        ch.set_source_rgba (ctx, 1.0, StyleType.BASE, Gtk.StateFlags.NORMAL);
        ctx.rectangle (spacer_allocation.x, spacer_allocation.y + BORDER_RADIUS, spacer_allocation.width, SHADOW_SIZE);
        ctx.fill ();
      }

      int width = this.get_allocated_width ();
      int height = spacer_allocation.y + BORDER_RADIUS + SHADOW_SIZE;
      
      // pattern
      Pattern pat = new Pattern.linear(0, 0, 0, height);
      r = g = b = 0.12;
      ch.get_color_colorized (ref r, ref g, ref b, StyleType.BG, StateFlags.SELECTED);
      pat.add_color_stop_rgba (0.0, r, g, b, 0.95);
      r = g = b = 0.4;
      ch.get_color_colorized (ref r, ref g, ref b, StyleType.BG, StateFlags.SELECTED);
      pat.add_color_stop_rgba (1.0, r, g, b, 1.0);
      
      r = g = b = 0.0;

      if (target_container.visible)
      {
        Gtk.Allocation target_container_allocation, tpane_allocation;
        target_container.get_allocation (out target_container_allocation);
        tpane.get_allocation (out tpane_allocation);

        width -= target_container_allocation.width;
        // draw background
        ctx.save ();
        ctx.translate (0.5, 0.5);
        ctx.set_operator (Operator.OVER);
        Utils.cairo_make_shadow_for_rect (ctx, target_container_allocation.x - BORDER_RADIUS, 
                                               tpane_allocation.y,
                                               target_container_allocation.width - 1 + BORDER_RADIUS,
                                               tpane_allocation.height - 1, 15, r, g, b, SHADOW_SIZE);
        ctx.translate (-0.5, -0.5);
        Utils.cairo_rounded_rect (ctx, target_container_allocation.x - BORDER_RADIUS, 
                                       tpane_allocation.y,
                                       target_container_allocation.width + BORDER_RADIUS,
                                       tpane_allocation.height, 15);
        ctx.set_operator (Operator.SOURCE);
        ctx.set_source (pat);
        ctx.clip ();
        ctx.paint ();
        if (model.searching_for == SearchingFor.TARGETS)
        {
          ctx.set_operator (Cairo.Operator.OVER);
          Utils.cairo_rounded_rect (ctx, tpane_allocation.x,
                                         tpane_allocation.y,
                                         tpane_allocation.width,
                                         tpane_allocation.height,
                                         15);
          ch.set_source_rgba (ctx, 0.3,
                              StyleType.FG, StateFlags.SELECTED);
          ctx.clip ();
          ctx.paint ();
        }
        ctx.restore ();
      }

      int delta = flag_selector_allocation.y - BORDER_RADIUS;
      if (!comp) delta = 0;
      
      ctx.save ();
      ctx.translate (SHADOW_SIZE, delta);
      width -= SHADOW_SIZE * 2;
      height -= SHADOW_SIZE + delta;
      // shadow
      ctx.translate (0.5, 0.5);
      ctx.set_operator (Operator.OVER);
      Utils.cairo_make_shadow_for_rect (ctx, 0, 0, width - 1, height - 1, BORDER_RADIUS, r, g, b, SHADOW_SIZE);
      ctx.translate (-0.5, -0.5);
      
      Utils.cairo_rounded_rect (ctx, 0, 0, width, height, BORDER_RADIUS);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      
      // reflection
      ctx.set_operator (Operator.OVER);
      ctx.new_path ();
      ctx.move_to (0, 0);
      ctx.rel_line_to (0.0, height / 3.0);
      ctx.rel_curve_to (width / 4.0, -height / 10.0, width / 4.0 * 3.0, -height / 10.0, width, 0.0);
      ctx.rel_line_to (0.0, -height / 3.0);
      ctx.close_path ();
      pat = new Pattern.linear (0, height / 10.0, 0, height / 3.0);
      pat.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 0.0);
      pat.add_color_stop_rgba (0.7, 1.0, 1.0, 1.0, 0.4);
      pat.add_color_stop_rgba (1.0, 1.0, 1.0, 1.0, 0.9);
      ctx.set_source (pat);
      ctx.clip ();
      ctx.paint ();

      ctx.restore ();
      
      // icon bgs
      ctx.set_operator (Operator.OVER);
      ctx.save ();
      Utils.cairo_rounded_rect (ctx, spane_allocation.x,
                                     spane_allocation.y,
                                     spane_allocation.width,
                                     spane_allocation.height,
                                     15);
      ch.set_source_rgba (ctx, model.searching_for == SearchingFor.SOURCES ? 0.3 : 0.08,
                          StyleType.FG, StateFlags.SELECTED);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      
      ctx.save ();
      Utils.cairo_rounded_rect (ctx, apane_allocation.x,
                                     apane_allocation.y,
                                     apane_allocation.width,
                                     apane_allocation.height,
                                     15);
      ch.set_source_rgba (ctx, model.searching_for == SearchingFor.ACTIONS ? 0.3 : 0.08,
                          StyleType.FG, StateFlags.SELECTED);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
    }
    
    private void update_labels ()
    {
      var focus = model.get_actual_focus ();
      if (focus.value == null)
      {
        if (controller.is_in_initial_state ())
        {
          source_label.set_text (IController.TYPE_TO_SEARCH);
          description_label.set_text (IController.DOWN_TO_SEE_RECENT);
        }
        else if (controller.searched_for_recent ())
        {
          description_label.set_text (IController.NO_RECENT_ACTIVITIES);
        }
        else
        {
          if (this.menuthrobber.active)
            description_label.set_text (IController.SEARCHING);
          else
            description_label.set_text (IController.NO_RESULTS);
        }
      }
      else
      {
        description_label.set_text (Utils.get_printable_description (focus.value));
      }
      if (model.searching_for == SearchingFor.TARGETS)
      {
        flag_selector.sensitive = false;
      }
      else
      {
        flag_selector.sensitive = true;
      }
      target_container.visible = model.needs_target ();
    }
    
    public override void update_focused_source (Entry<int, Match> m)
    {
      if (controller.is_in_initial_state ()) source_icon.set_icon_name ("search");
      else if (m.value == null) source_icon.set_icon_name ("");
      else
      {
        if (m.value.has_thumbnail)
          source_icon.set_icon_name (m.value.thumbnail_path);
        else
          source_icon.set_icon_name (m.value.icon_name);
        results_sources.move_selection_to_index (m.key);
      }
      source_label.set_markup (Utils.markup_string_with_search (m.value == null ? "" : m.value.title, this.model.query[SearchingFor.SOURCES], ""));
      if (model.searching_for == SearchingFor.SOURCES) update_labels ();
    }
    
    public override void update_focused_action (Entry<int, Match> m)
    {
      if (controller.is_in_initial_state () ||
          model.focus[SearchingFor.SOURCES].value == null)
      {
        action_icon.clear ();
      }
      else if (m.value == null)
      {
        action_icon.set_icon_name ("");
      }
      else
      {
        action_icon.set_icon_name (m.value.icon_name);
        results_actions.move_selection_to_index (m.key);
      }
      action_label.set_markup (Utils.markup_string_with_search (m.value == null ? "" : m.value.title, this.model.query[SearchingFor.ACTIONS], ""));
      if (model.searching_for == SearchingFor.ACTIONS) update_labels ();
    }
    
    public override void update_focused_target (Entry<int, Match> m)
    {
      if (m.value == null) target_icon.set_icon_name ("");
      else
      {
        if (m.value is DefaultMatch)
          target_icon.set_icon_name ("text-plain");
        else
        {
          if (m.value.has_thumbnail)
            target_icon.set_icon_name (m.value.thumbnail_path);
          else
            target_icon.set_icon_name (m.value.icon_name);
        }
        results_targets.move_selection_to_index (m.key);
      }
      target_label.set_markup (Utils.markup_string_with_search (m.value == null ? "" : m.value.title, this.model.query[SearchingFor.TARGETS], ""));
      if (model.searching_for == SearchingFor.TARGETS) update_labels ();
    }
    
    public override void update_sources (Gee.List<Match>? list = null)
    {
      results_sources.update_matches (list);
    }
    public override void update_actions (Gee.List<Match>? list = null)
    {
      results_actions.update_matches (list);
    }
    public override void update_targets (Gee.List<Match>? list = null)
    {
      results_targets.update_matches (list);
    }
  }
}
