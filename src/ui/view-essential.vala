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
  public class ViewEssential : Synapse.Gui.View
  {
    construct {
      
    }
    
    public override void style_updated ()
    {
      base.style_updated ();
      update_bg_state ();
      
      int width, icon_size;
      string tmax, tmin;
      style_get ("ui-width", out width, "icon-size", out icon_size, "title-size", out tmax,
        "title-min-size", out tmin);
      
      icon_container.scale_size = icon_size;
      container.set_size_request (width, -1);
      spacer.set_size_request (1, SHADOW_SIZE + BORDER_RADIUS);
      focus_label.size = SmartLabel.string_to_size (tmax);
      focus_label.min_size = SmartLabel.string_to_size (tmin);
    }
    
    private void update_bg_state ()
    {
      flag_selector.set_state_flags (this.bg_state, false);
      results_sources.set_state_flags (this.bg_state, false);
      results_actions.set_state_flags (this.bg_state, false);
      results_targets.set_state_flags (this.bg_state, false);
      menuthrobber.set_state_flags (this.bg_state, false);
    }
    
    private NamedIcon source_icon;
    private NamedIcon action_icon;
    private NamedIcon target_icon;
    
    private SmartLabel focus_label;
    
    private SchemaContainer icon_container;
    
    private Box container;
    
    private SelectionContainer results_container;
    
    private ResultBox results_sources;
    private ResultBox results_actions;
    private ResultBox results_targets;
    
    private MenuThrobber menuthrobber;
    
    protected override void build_ui ()
    {
      container = new Box (Gtk.Orientation.VERTICAL, 0);
      /* Icons */
      source_icon = new NamedIcon ();
      action_icon = new NamedIcon ();
      target_icon = new NamedIcon ();
      source_icon.set_icon_name ("search", IconSize.DND);
      action_icon.clear ();
      target_icon.set_icon_name ("");
      
      icon_container = new SchemaContainer (96);
      icon_container.fixed_height = true;
      icon_container.add (source_icon);
      icon_container.add (action_icon);
      icon_container.add (target_icon);
      var schema = new SchemaContainer.Schema (); // searcing for sources
      schema.add_allocation ({ 30, 0, 100, 100 });
      schema.add_allocation ({ 0, 50, 50, 50 });
      icon_container.add_schema (schema);
      schema = new SchemaContainer.Schema (); // searcing for sources with target
      schema.add_allocation ({ 30, 0, 100, 100 });
      schema.add_allocation ({ 0, 50, 50, 50 });
      schema.add_allocation ({ 0, 0, 50, 50 });
      icon_container.add_schema (schema);
      schema = new SchemaContainer.Schema (); // searching for actions, but no target
      schema.add_allocation ({ 0, 50, 50, 50 });
      schema.add_allocation ({ 30, 0, 100, 100 });
      icon_container.add_schema (schema);
      schema = new SchemaContainer.Schema (); // searching for actions, with target
      schema.add_allocation ({ 0, 50, 50, 50 });
      schema.add_allocation ({ 30, 0, 100, 100 });
      schema.add_allocation ({ 0, 0, 50, 50 });
      icon_container.add_schema (schema);
      schema = new SchemaContainer.Schema (); // searching for target
      schema.add_allocation ({ 0, 50, 50, 50 });
      schema.add_allocation ({ 0, 0, 50, 50 });
      schema.add_allocation ({ 30, 0, 100, 100 });
      icon_container.add_schema (schema);
      
      icon_container.show ();
      /* Labels */
      focus_label = new SmartLabel ();
      focus_label.set_ellipsize (Pango.EllipsizeMode.END);
      focus_label.size = SmartLabel.Size.LARGE;
      focus_label.min_size = SmartLabel.Size.MEDIUM;
      focus_label.xpad = 3;
      
      /* Categories - Throbber and menu */ //#0C71D6
      var categories_hbox = new Box (Gtk.Orientation.HORIZONTAL, 0);

      menuthrobber = new MenuThrobber ();
      menu = (MenuButton) menuthrobber;
      menuthrobber.set_size_request (14, 14);

      categories_hbox.pack_start (flag_selector);
      categories_hbox.pack_start (menuthrobber, false);

      var vb = new Box (Gtk.Orientation.VERTICAL, 0);
      // vb.pack_end (description_label, false);
      var fi = new FakeInput ();
      fi.border_radius = 5;
      fi.border_width = 5;
      fi.add (focus_label);
      vb.pack_end (fi, false, false, 2);
      vb.pack_end (categories_hbox, false);

      flag_selector.selected_markup = "<span size=\"small\"><b>%s</b></span>";
      flag_selector.unselected_markup = "<span size=\"x-small\">%s</span>";
      
      /* Top Container */
      var hb = new Box (Gtk.Orientation.HORIZONTAL, 5);
      var sensitive = new SensitiveWidget (icon_container);
      this.make_draggable (sensitive);
      hb.pack_start (sensitive, false);
      hb.pack_start (vb, true);
      
      container.pack_start (hb, false);
      container.pack_start (spacer, false);
      
      /* list */
      this.prepare_results_container (out results_container, out results_sources,
                                      out results_actions, out results_targets, StateFlags.NORMAL);
      container.pack_start (results_container, false);
      
      container.show_all ();
      results_container.hide ();

      container.set_size_request (500, -1);
      this.add (container);
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
    }
    
    public override void update_selected_category ()
    {
      flag_selector.selected = model.selected_category;
    }
    
    protected override void paint_background (Cairo.Context ctx)
    {
      bool comp = this.is_composited ();
      double r = 0, b = 0, g = 0;

      Gtk.Allocation spacer_allocation, flag_selector_allocation;
      spacer.get_allocation (out spacer_allocation);
      flag_selector.get_allocation (out flag_selector_allocation);

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
      
      ctx.save ();
      // pattern
      Pattern pat = new Pattern.linear(0, 0, 0, height);
      if (this.bg_state == Gtk.StateFlags.SELECTED)
      {
        r = g = b = 0.5;
        ch.get_color_colorized (ref r, ref g, ref b, StyleType.BG, this.bg_state);
        pat.add_color_stop_rgba (0.0, r, g, b, 0.95);
        r = g = b = 0.15;
        ch.get_color_colorized (ref r, ref g, ref b, StyleType.BG, this.bg_state);
        pat.add_color_stop_rgba (1.0, r, g, b, 1.0);
      }
      else
      {
        ch.add_color_stop_rgba (pat, 0.0, 0.95, StyleType.BG, this.bg_state, Mod.LIGHTER);
        ch.add_color_stop_rgba (pat, 1.0, 1.0, StyleType.BG, this.bg_state, Mod.NORMAL);
      }
      Utils.cairo_rounded_rect (ctx, 0, 0, width, height, BORDER_RADIUS);
      ctx.set_source (pat);
      ctx.set_operator (Operator.SOURCE);
      ctx.clip ();
      ctx.paint ();
      ctx.restore ();
      
      //border
      ctx.translate (- 0.5, - 0.5);      
      Utils.cairo_rounded_rect (ctx, 0, 0, width + 1, height + 1, BORDER_RADIUS);
      ctx.set_line_width (1.0);
      ctx.set_operator (Cairo.Operator.OVER);
      ctx.set_source_rgba (0.0, 0.0, 0.0, 0.5);
      ctx.stroke ();

      ctx.restore ();
    }
    
    private void update_labels ()
    {
      var focus = model.get_actual_focus ();
      if (focus.value == null)
      {
        if (controller.is_in_initial_state ())
        {
          focus_label.set_text (IController.TYPE_TO_SEARCH);
        }
        else if (controller.searched_for_recent ())
        {
          focus_label.set_text ("");
        }
        else
        {
          focus_label.set_text (this.model.query[model.searching_for]);
        }
      }
      else
      {
        focus_label.set_markup (Utils.markup_string_with_search (focus.value.title, this.model.query[model.searching_for], ""));
      }
      switch (model.searching_for)
      {
        case SearchingFor.SOURCES:
          flag_selector.sensitive = true;
          if (model.needs_target ())
          {
            icon_container.select_schema (1);
          }
          else
          {
            icon_container.select_schema (0);
          }
          icon_container.set_render_order ({2, 0, 1});
          break;
        case SearchingFor.ACTIONS:
          if (model.needs_target ())
          {
            icon_container.select_schema (3);
          }
          else
          {
            icon_container.select_schema (2);
          }
          icon_container.set_render_order ({0, 2, 1});
          flag_selector.sensitive = true;
          break;
        default: //case SearchingFor.TARGETS:
          icon_container.select_schema (4);
          icon_container.set_render_order ({2, 0, 1});
          flag_selector.sensitive = false;
          break;
      }
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
      if (model.searching_for == SearchingFor.SOURCES) update_labels ();
    }
    
    public override void update_focused_action (Entry<int, Match> m)
    {
      if (controller.is_in_initial_state () ||
          model.focus[SearchingFor.SOURCES].value == null) action_icon.clear ();
      else if (m.value == null) action_icon.set_icon_name ("");
      else
      {
        action_icon.set_icon_name (m.value.icon_name);
        results_actions.move_selection_to_index (m.key);
      }
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
          target_icon.set_icon_name (m.value.icon_name);
        results_targets.move_selection_to_index (m.key);
      }
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
