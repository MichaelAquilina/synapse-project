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

using Gtk;

namespace Synapse
{
  /* Gtk+-3.0 base class */
  public class Gui.View : Gtk.Window, Synapse.Gui.IView
  {
    /* --- base class for gtk+-3.0 --- */

    protected bool is_kwin = false;
    
    private void update_wm ()
    {
      string wmname = Gdk.X11Screen.get_window_manager_name (Gdk.Screen.get_default ()).down ();
      this.is_kwin = wmname == "kwin";
    }
    
    private Requisition req_target;
    private Requisition req_current;
    
    protected Gui.Utils.ColorHelper ch;
    protected HTextSelector flag_selector;
    protected MenuButton menu;
    
    protected Label spacer;

    protected int BORDER_RADIUS;
    protected int SHADOW_SIZE;
    protected Gtk.StateFlags bg_state;
    
    protected bool cache_enabled;
    protected Gee.Map<string, Cairo.Surface> bg_cache;
    
    static construct
    {
      var bg_style = new GLib.ParamSpecBoolean ("use-selected-color",
                                                "Use selected color",
                                                "Use selected color for the background of Synapse in supported themes",
                                                false,
                                                GLib.ParamFlags.READWRITE);

      var border_radius = new GLib.ParamSpecInt ("border-radius",
                                                 "Border Radius",
                                                 "Border Radius of Synapse window",
                                                 0, 50, 12,
                                                 GLib.ParamFlags.READWRITE);
      var shadow_size = new GLib.ParamSpecInt ("shadow-size",
                                               "Shadow Size",
                                               "Shadow size of Synapse window",
                                               0, 50, 13,
                                               GLib.ParamFlags.READWRITE);

      var width = new GLib.ParamSpecInt ("ui-width",
                                         "Width",
                                         "The width of the content in supported themes",
                                         0, 1024, 560,
                                         GLib.ParamFlags.READWRITE);

      var spacing = new GLib.ParamSpecInt ("pane-spacing",
                                             "Pane Spacing",
                                             "The space between panes in supported themes",
                                             5, 100, 30,
                                             GLib.ParamFlags.READWRITE);

      var icon_size = new GLib.ParamSpecInt ("icon-size",
                                             "Icon Size",
                                             "The size of focused icon in supported themes",
                                             32, 256, 128,
                                             GLib.ParamFlags.READWRITE);

      var title_max = new GLib.ParamSpecString ("title-size",
                                                "Title Font Size",
                                                "The standard size the match title in Pango absolute sizes (string)",
                                                "x-large",
                                                GLib.ParamFlags.READWRITE);
      var title_min = new GLib.ParamSpecString ("title-min-size",
                                                "Title minimum Font Size",
                                                "The minimum size the match title in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READWRITE);
      var descr_max = new GLib.ParamSpecString ("description-size",
                                                "Description Font Size",
                                                "The standard size the match description in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READWRITE);
      var descr_min = new GLib.ParamSpecString ("description-min-size",
                                                "Description minimum Font Size",
                                                "The minimum size the match description in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READWRITE);
      var cat_max = new GLib.ParamSpecString ("selected-category-size",
                                                "Selected Category Font Size",
                                                "Font size of selected category in Pango absolute sizes (string)",
                                                "medium",
                                                GLib.ParamFlags.READWRITE);
      var cat_min = new GLib.ParamSpecString ("unselected-category-size",
                                                "Unselected Category Font Size",
                                                "Font size of unselected categories in Pango absolute sizes (string)",
                                                "small",
                                                GLib.ParamFlags.READWRITE);
      
      install_style_property (width);
      install_style_property (bg_style);
      install_style_property (spacing);
      install_style_property (icon_size);
      install_style_property (title_max);
      install_style_property (title_min);
      install_style_property (descr_max);
      install_style_property (descr_min);
      install_style_property (cat_max);
      install_style_property (cat_min);
      install_style_property (border_radius);
      install_style_property (shadow_size);
    }
    
    private Requisition old_alloc;

    construct
    {
      model = controller_model;
      old_alloc = {1, 1};
      update_wm ();
      if (is_kwin) Synapse.Utils.Logger.log (this, "Using KWin compatibility mode.");
      
      cache_enabled = true;
      bg_cache = new Gee.HashMap<string, Cairo.Surface> ();
      bg_state = Gtk.StateFlags.SELECTED;
      
      req_target = {0, 0};
      req_current = {0, 0};
      
      style_get ("border-radius", out BORDER_RADIUS,
        "shadow-size", out SHADOW_SIZE);
      
      this.set_app_paintable (true);
      this.skip_taskbar_hint = true;
      this.skip_pager_hint = true;
      this.set_position (Gtk.WindowPosition.CENTER);
      this.set_decorated (false);
      this.set_resizable (false);

      /* SPLASHSCREEN is needed for Metacity/Compiz, but doesn't work with KWin */
      if (is_kwin)
        this.set_type_hint (Gdk.WindowTypeHint.NORMAL);
      else
        this.set_type_hint (Gdk.WindowTypeHint.SPLASHSCREEN);
      this.set_keep_above (true);

      /* Listen on click events */
      this.set_events (this.get_events () | Gdk.EventMask.BUTTON_PRESS_MASK
                                          | Gdk.EventMask.KEY_PRESS_MASK);

      Gui.Utils.ensure_transparent_bg (this);
      
      ch = Gui.Utils.ColorHelper.get_default ();
      
      // only needed to execute the static construct of SmartLabel
      var initialize_smartlabel = new SmartLabel ();
      
      // init the category selector
      flag_selector = new HTextSelector ();
      foreach (CategoryConfig.Category c in controller.category_config.categories)
      {
        flag_selector.add_text (c.name);
      }
      flag_selector.selected = controller.category_config.default_category_index;
      flag_selector.selection_changed.connect (()=>{
        controller.category_changed_event (flag_selector.selected);
      });
      
      /* Use the spacer to separate the list from the main section of the window
       * the spacer will fill up the space equal to the rounded border plus the shadow
       */
      spacer = new Label (null);
      spacer.set_size_request (1, SHADOW_SIZE + BORDER_RADIUS);
      
      menu = null;
      
      build_ui ();
      
      composited_changed ();

      if (menu != null)
      {
        menu.get_menu ().show.connect (this.force_grab);
        menu.settings_clicked.connect (()=>{ controller.show_settings_requested (); });
      }

       // gtk3 no longer calls this itself on startup
       style_updated ();
    }
    
    protected virtual void build_ui ()
    {
      
    }
    
    public override void size_allocate (Gtk.Allocation alloc)
    {
      base.size_allocate (alloc);

      Gtk.Allocation allocation;
      this.get_allocation (out allocation);

      if (this.is_kwin && 
          (old_alloc.width != allocation.width || 
           old_alloc.height != allocation.height)
         )
      {
        this.add_kde_compatibility (this, allocation.width, allocation.height);
        this.old_alloc = {
          allocation.width,
          allocation.height
        };
      }
    }
    
    public override void composited_changed ()
    {
      Gdk.Screen screen = this.get_screen ();
      bool comp = screen.is_composited ();
      Gdk.Visual? visual = screen.get_rgba_visual();
      if (visual == null)
      {
        comp = false;
        visual = screen.get_system_visual();
      }
      Synapse.Utils.Logger.log (this, "Screen is%s composited.", comp ? "": " NOT");
      this.set_visual (visual);

      update_wm ();
      update_border_and_shadow ();
    }
    
    protected void add_kde_compatibility (Gtk.Window window, int w, int h)
    {
      /* Fix to the horrible shadow glitches in KDE 4 */
      /* If shape mask is set, KWin will not add that horrible shadow */
      var region = new Cairo.Region.rectangle ({0, 0, w, h});
      var gdkwin = window.get_window ();
      gdkwin.shape_combine_region (null, 0, 0);
      gdkwin.shape_combine_region (region, 0, 0);
    }
    
    public override void style_updated ()
    {
      base.style_updated ();
      string dmax, dmin;
      bool bgselected;
      style_get ("use-selected-color", out bgselected, "selected-category-size", out dmax,
        "unselected-category-size", out dmin);
      this.bg_state = bgselected ? StateFlags.SELECTED : StateFlags.NORMAL;
      flag_selector.selected_markup = "<span size=\"%s\"><b>%s</b></span>".printf (
                                                      SmartLabel.size_to_string[SmartLabel.string_to_size (dmax)], "%s");
      flag_selector.unselected_markup = "<span size=\"%s\">%s</span>".printf (
                                                      SmartLabel.size_to_string[SmartLabel.string_to_size (dmin)], "%s");
      this.bg_cache.clear ();
      update_border_and_shadow ();
    }
    
    protected void update_border_and_shadow ()
    {
      if (this.is_composited ())
      {
        style_get ("border-radius", out BORDER_RADIUS, "shadow-size", out SHADOW_SIZE);
      }
      else
      {
        BORDER_RADIUS = 0;
        SHADOW_SIZE = 1;
      }

      this.border_width = BORDER_RADIUS + SHADOW_SIZE;
      this.spacer.set_size_request (1, SHADOW_SIZE + BORDER_RADIUS);

      this.queue_resize ();
      this.queue_draw ();
    }
    
    public override bool button_press_event (Gdk.EventButton event)
    {
      int x = (int)event.x_root;
      int y = (int)event.y_root;
      int rx, ry;
      this.get_window ().get_root_origin (out rx, out ry);

      if (!Gui.Utils.is_point_in_mask (this, x - rx, y - ry)) this.vanish ();

      return false;
    }
    
    public override bool key_press_event (Gdk.EventKey event)
    {
      this.controller.key_press_event (event);
      return false;
    }

    public override bool draw (Cairo.Context ctx)
    {
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();

      /* Propagate Draw */
      this.propagate_draw (this.get_child(), ctx);
      
      ctx.rectangle (0, 0, this.get_allocated_width (), this.get_allocated_height ());
      ctx.clip ();
      
      string key = "%dx%dx%d".printf (this.get_allocated_width (), this.get_allocated_height (), model.searching_for);
      
      if (cache_enabled)
      {
        if (this.bg_cache.has_key (key))
        {
          ctx.set_source_surface (this.bg_cache[key], 0, 0);
        }
        else
        {
          Cairo.Surface surf = new Cairo.Surface.similar (ctx.get_target (),
                                                          Cairo.Content.COLOR_ALPHA,
                                                          this.get_allocated_width (),
                                                          this.get_allocated_height ());
          Cairo.Context cr = new Cairo.Context (surf);
          paint_background (cr);
          bg_cache[key] = surf;
          ctx.set_source_surface (surf, 0, 0);
        }
      }
      else
      {
        ctx.push_group ();
        paint_background (ctx);
        ctx.pop_group_to_source ();
      }

      ctx.set_operator (Cairo.Operator.DEST_OVER);
      ctx.paint ();

      return true;
    }
    
    protected virtual void prepare_results_container (out SelectionContainer? results_container,
                                                      out ResultBox results_sources,
                                                      out ResultBox results_actions,
                                                      out ResultBox results_targets,
                                                      Gtk.StateFlags state_type = Gtk.StateFlags.NORMAL,
                                                      bool add_to_container = true)
    {
      results_sources = new ResultBox (100);
      results_actions = new ResultBox (100);
      results_targets = new ResultBox (100);
      /* regrab mouse after drag */
      results_sources.get_match_list_view ().drag_end.connect (drag_end_handler);
      results_actions.get_match_list_view ().drag_end.connect (drag_end_handler);
      results_targets.get_match_list_view ().drag_end.connect (drag_end_handler);
      /* listen on scroll / click / dblclick */
      results_sources.get_match_list_view ().selected_index_changed.connect (controller.selected_index_changed_event);
      results_actions.get_match_list_view ().selected_index_changed.connect (controller.selected_index_changed_event);
      results_targets.get_match_list_view ().selected_index_changed.connect (controller.selected_index_changed_event);
      results_sources.get_match_list_view ().fire_item.connect (controller.fire_focus);
      results_actions.get_match_list_view ().fire_item.connect (controller.fire_focus);
      results_targets.get_match_list_view ().fire_item.connect (controller.fire_focus);

      if (add_to_container)
      {
        results_container = new SelectionContainer ();
        results_container.add (results_sources);
        results_container.add (results_actions);
        results_container.add (results_targets);
      }
      else
      {
        results_container = null;
      }

      results_sources.set_state (state_type);
      results_actions.set_state (state_type);
      results_targets.set_state (state_type);
    }
    
    protected virtual void paint_background (Cairo.Context ctx)
    {
      ch.set_source_rgba (ctx, 0.9, StyleType.BG, StateFlags.NORMAL);
      ctx.set_operator (Cairo.Operator.SOURCE);
      ctx.paint ();
    }

    public void force_grab ()
    {
      Gui.Utils.present_window (this);
    }
    
    public virtual void summon ()
    {
      this.set_list_visible (true);
      Gui.Utils.move_window_to_center (this);
      this.set_list_visible (false);
      this.show ();
      if (this.is_kwin) this.add_kde_compatibility (this, this.get_allocated_width (), this.get_allocated_height ());
      Gui.Utils.present_window (this);
      this.queue_draw ();
      this.summoned ();
    }

    public virtual void vanish ()
    {
      Gui.Utils.unpresent_window (this);
      this.hide ();
      this.vanished ();
      IconCacheService.get_default ().reduce_cache ();
    }

    public virtual void summon_or_vanish ()
    {
      if (this.visible)
        vanish ();
      else
        summon ();
    }
    
    private string dragdrop_name = "";
    private string dragdrop_uri = "";

    protected void make_draggable (EventBox obj)
    {
      obj.set_events (obj.get_events () | Gdk.EventMask.BUTTON_PRESS_MASK);
      // D&D
      Gtk.drag_source_set (obj, Gdk.ModifierType.BUTTON1_MASK, {}, 
                               Gdk.DragAction.ASK | 
                               Gdk.DragAction.COPY | 
                               Gdk.DragAction.MOVE | 
                               Gdk.DragAction.LINK);
      obj.button_press_event.connect (this.draggable_clicked);
      obj.drag_data_get.connect (this.draggable_get);
      obj.drag_end.connect (drag_end_handler);
      //TODO: drag data recieved => vanish
    }
    
    protected void drag_end_handler (Widget w, Gdk.DragContext context)
    {
      this.force_grab ();
    }
    
    private void draggable_get (Widget w, Gdk.DragContext context, SelectionData selection_data, uint info, uint time_)
    {
      /* Called at drop time */
      selection_data.set_text (dragdrop_name, -1);
      selection_data.set_uris ({dragdrop_uri});
    }
    
    private bool draggable_clicked (Gtk.Widget w, Gdk.EventButton event)
    {
      var tl = new TargetList ({});
      var sf = model.searching_for;
      if (sf == SearchingFor.ACTIONS) sf = SearchingFor.SOURCES;
      if (model.focus[sf].value == null)
      {
        dragdrop_name = "";
        dragdrop_uri = "";
        Gtk.drag_source_set_target_list (w, tl);
        Gtk.drag_source_set_icon_stock (w, Gtk.Stock.MISSING_IMAGE);
        return false;
      }

      UriMatch? um = model.focus[sf].value as UriMatch;
      if (um == null)
      {
        dragdrop_name = "";
        dragdrop_uri = "";
        Gtk.drag_source_set_target_list (w, tl);
        Gtk.drag_source_set_icon_stock (w, Gtk.Stock.MISSING_IMAGE);
        return false;
      }
      
      dragdrop_name = um.title;
      dragdrop_uri = um.uri;
      tl.add_text_targets (0);
      tl.add_uri_targets (1);
      Gtk.drag_source_set_target_list (w, tl);
      
      try {
        var icon = GLib.Icon.new_for_string (um.icon_name);
        if (icon == null) return false;

        Gtk.IconInfo iconinfo = Gtk.IconTheme.get_default ().lookup_by_gicon (icon, 48, Gtk.IconLookupFlags.FORCE_SIZE);
        if (iconinfo == null) return false;

        Gdk.Pixbuf icon_pixbuf = iconinfo.load_icon ();
        if (icon_pixbuf == null) return false;
        
        Gtk.drag_source_set_icon_pixbuf (w, icon_pixbuf);
      }
      catch (GLib.Error err) {}
      return false;
    }
    
    protected Synapse.Gui.Model model = null;
    
    public Synapse.Gui.Model controller_model {get; construct set;}
    public Synapse.Gui.IController controller {get; construct set;}
    
    public virtual void update_focused_source (Entry<int, Match> m){}
    public virtual void update_focused_action (Entry<int, Match> m){}
    public virtual void update_focused_target (Entry<int, Match> m){}

    public virtual void update_sources (Gee.List<Match>? list = null){}
    public virtual void update_actions (Gee.List<Match>? list = null){}
    public virtual void update_targets (Gee.List<Match>? list = null){}
    
    public virtual void update_selected_category (){}
    
    public virtual void update_searching_for (){}
    
    public virtual bool is_list_visible (){ return true; }
    public virtual void set_list_visible (bool visible){}
    public virtual void set_throbber_visible (bool visible){}
  }
}
