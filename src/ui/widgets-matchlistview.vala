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
using Cairo;
using Gee;

namespace Synapse.Gui
{
  public class MatchViewRenderer : MatchListView.MatchViewRendererBase
  {
    // the size of Match and Action icons
    public int icon_size {get; set; default = 32;}
    // top and bottom row's padding
    public int cell_vpadding {get; set; default = 2;}
    // left and right padding on each component of the row
    public int cell_hpadding {get; set; default = 3;}
    //hilight matched text into selected match's title
    public bool hilight_on_selected {get; set; default = false;}
    //shows the pattern after the title if hilight doesn't match the title
    public bool show_pattern_in_hilight {get; set; default = false;}
    //shows extended info when present (ie "xx minutes ago")
    public bool show_extended_info {get; set; default = true;}
    //hides extended info on selected row if present
    public bool hide_extended_on_selected {get; set; default = false;}
    //overlay action icon to the text, or reserve space for action icon shrinking labels
    public bool overlay_action {get; set; default = false;}
    //the string pattern to use in the hilight
    public new string pattern {get; set; default = "";}
    //the Action match to use to retrive the action icon to show
    public Match action {get; set; default = null;}
    //the markup of the title
    public string title_markup {get; set; default = "<span size=\"medium\"><b>%s</b></span>";}
    //the markup of the description
    public string description_markup {get; set; default = "<span size=\"small\">%s</span>";}
    //the markup of the extended info **extend info is already inserted into description markup**
    public string extended_info_markup {get; set; default = "%s";}
    
    private int text_height;
    
    construct
    {
      this.text_height = 1;
      this.get_layout ().set_ellipsize (Pango.EllipsizeMode.END);
      
      this.notify["icon-size"].connect (size_changed);
      this.notify["cell-vpadding"].connect (size_changed);
      this.notify["cell-hpadding"].connect (size_changed);
      this.notify["title-markup"].connect (size_changed);
      this.notify["description-markup"].connect (size_changed);
    }
    
    public override void render_match (Cairo.Context ctx, Match m, int width, int height, bool use_base = false, double selected_pct = 1.0)
    {
      /* _____   ____________________________   _____
        |     | |                            | |     |
        |     | |____________________________| |     |
        |_____| |____|__________________|____| |_____|
      */
      ctx.set_operator (Cairo.Operator.OVER);
      //rtl = Gtk.TextDirection.RTL; // <-- uncomment to test RTL
      bool has_action = false;
      Gtk.StateType state = Gtk.StateType.NORMAL;
      if (selected_pct > 1.0)
      {
        state = Gtk.StateType.SELECTED;
        selected_pct = selected_pct - 1.0;
      }
      if (state == Gtk.StateType.SELECTED && action != null) has_action = true;

      int x = 0, y = 0;
      int text_width = width - cell_hpadding * 4 - icon_size;
      if (has_action && !overlay_action) text_width = text_width - cell_hpadding * 2 - icon_size;

      if (rtl != Gtk.TextDirection.RTL)
      {
        /* Match Icon */
        x = cell_hpadding;
        y = (height - icon_size) / 2;
        draw_icon (ctx, m, x, y);

        /* Title and description */
        x += icon_size + cell_hpadding * 2;
        y = (height - text_height) / 2;
        draw_text (ctx, m, x, y, text_width, state, use_base, selected_pct);

        /* Action Icon */
        if (has_action)
        {
          y = (height - icon_size) / 2;
          draw_action (ctx, width - cell_hpadding - icon_size, y, selected_pct);
        }
      }
      else
      {
        /* Match Icon */
        x = width - cell_hpadding - icon_size;
        y = (height - icon_size) / 2;
        draw_icon (ctx, m, x, y);

        /* Title and description */
        x = x - cell_hpadding * 2 - text_width;
        y = (height - text_height) / 2;
        draw_text (ctx, m, x, y, text_width, state, use_base, selected_pct);
        
        /* Action Icon */
        if (has_action)
        {
          y = (height - icon_size) / 2;
          draw_action (ctx, cell_hpadding, y, selected_pct);
        }
      }
    }
    protected override int calculate_row_height ()
    {
      string s = "%s\n%s".printf (title_markup, description_markup);
      Markup.printf_escaped (s, " &#21271;", " &#21271;");
      var layout = this.get_layout ();
      layout.set_markup (s, -1);
      int width = 0, height = 0;
      layout.get_pixel_size (out width, out height);
      this.text_height = height;
      height = int.max (this.icon_size, height) + cell_vpadding * 2;
      return height;
    }
    
    private void size_changed ()
    {
      calculate_row_height ();
      this.queue_resize ();
    }
    
    private void draw_icon (Cairo.Context ctx, Match m, int x, int y)
    {
      ctx.save ();
      ctx.translate (x, y);
      draw_icon_in_position (ctx, m.icon_name, icon_size);
      ctx.restore ();
    }
    private void draw_action (Cairo.Context ctx, int x, int y, double selected_fill_pct)
    {
      if (selected_fill_pct < 0.9) return;
      if (selected_fill_pct < 1.0) selected_fill_pct /= 3.0;
      ctx.save ();
      ctx.translate (x, y);
      draw_icon_in_position (ctx, action.icon_name, icon_size, selected_fill_pct);
      ctx.restore ();
    }

    private void draw_text (Cairo.Context ctx, Match m, int x, int y, int width, Gtk.StateType state, bool use_base, double selected_fill_pct)
    {
      ctx.save ();
      ctx.translate (x, y);
      ctx.rectangle (0, 0, width, text_height);
      ctx.clip ();
      
      bool selected = (state == Gtk.StateType.SELECTED);

      var styletype = ch.StyleType.FG;
      if (use_base || selected) styletype = ch.StyleType.TEXT;
      
      if (selected && selected_fill_pct < 1.0)
      {
        double r = 0, g = 0, b = 0;
        ch.get_rgb_from_mix (styletype, Gtk.StateType.NORMAL, ch.Mod.NORMAL,
                             styletype, Gtk.StateType.SELECTED, ch.Mod.NORMAL,
                             selected_fill_pct, out r, out g, out b);
        ctx.set_source_rgba (r, g, b, 1.0);
      }
      else ch.set_source_rgba (ctx, 1.0, styletype, state);

      string s = "";
      /* ----------------------- draw title --------------------- */
      if (hilight_on_selected && selected && selected_fill_pct == 1.0)
      {
        s = title_markup.printf (Utils.markup_string_with_search (m.title, pattern, "", show_pattern_in_hilight));
      }
      else
      {
        s = Markup.printf_escaped (title_markup, m.title);
      }
      layout.set_markup (s, -1);
      layout.set_width (Pango.SCALE * width);
      Pango.cairo_show_layout (ctx, layout);

      bool has_extended_info = show_extended_info && (m is ExtendedInfo);
      if (hide_extended_on_selected && selected) has_extended_info = false;
      int width_for_description = width - cell_hpadding;
      
      /* ----------------- draw extended info ------------------- */
      if (has_extended_info)
      {
        ctx.save ();
        s = Markup.printf_escaped (extended_info_markup, (m as ExtendedInfo).extended_info ?? "");
        s = description_markup.printf (s);
        layout.set_markup (s, -1);
        layout.set_width (Pango.SCALE * width_for_description);
        int w = 0, h = 0;
        layout.get_pixel_size (out w, out h);
        w += _cell_hpadding * 2;
        
        width_for_description -= w;
        
        if (rtl == Gtk.TextDirection.RTL) 
          ctx.translate (- width + w, text_height - h);
        else
          ctx.translate (width - w, text_height - h);
        Pango.cairo_show_layout (ctx, layout);
        ctx.restore ();
      }
      
      /* ------------------ draw description --------------------- */
      s = Markup.printf_escaped (description_markup, Utils.get_printable_description (m));

      layout.set_markup (s, -1);
      layout.set_width (Pango.SCALE * width_for_description);
      int w = 0, h = 0;
      layout.get_pixel_size (out w, out h);
      
      if (rtl == Gtk.TextDirection.RTL) 
        ctx.translate (width - width_for_description, text_height - h);
      else
        ctx.translate (0, text_height - h);

      Pango.cairo_show_layout (ctx, layout);
      ctx.restore ();
    }
  }

  public class MatchListView : Gtk.EventBox
  {
    /* Animation stuffs */
    private uint tid;
    private static const int ANIM_TIMEOUT = 1000 / 26;
    public bool animation_enabled {
      get; set; default = true;
    }

    private int offset; //current offset
    private int toffset; //target offset

    private int soffset; //current selection offset
    private int tsoffset; //target selection offset
    
    private int row_height; //fixed row height (usually icon_size + 4)

    /* _________________      -> 0 coord for offset
       |                |
    ___|________________|___  -> offset            -> 0 coord for soffset
    |                       |
    |#######################| => selection -> soffset
    |                       | => visible area
    |_______________________|
       |                |
       |                |
       |                |
       |________________|
    */
    
    private Gee.List<Match> items;
    private int goto_index;
    private int select_index;
    
    public void set_indexes (int targetted, int selected)
    {
      bool b = _select(selected);
      b = _goto(targetted) || b;
      if (b) this.update_target_offsets ();
    }

    public int selected_index {
      get {
        return this.select_index;
      }
    }
    
    public int targetted_index {
      get {
        return this.goto_index;
      }
    }
    
    public bool selection_enabled
    {
      get; set; default = true;
    }
    
    public bool use_base_colors
    {
      get; set; default = true;
    }
    
    public int min_visible_rows
    {
      get; set; default = 5;
    }
    
    private bool inhibit_move;
    
    public enum Behavior
    {
      TOP,
      CENTER,
      BOTTOM,
      TOP_FORCED,
      CENTER_FORCED,
      BOTTOM_FORCED
    }
    public Behavior behavior
    {
      get;
      set;
      default = Behavior.CENTER;
    }
    
    public class MatchViewRendererBase : Gtk.Label
    {
      /* Methods to override here */
      
      /* render_match:
         use_base : if true use gtk.BASE/TEXT, else use gtk.BG/FG
         selected_pct : [1.0 - 2.0] -> 
          if > 1.0 then
            selected = true
            pct = selected_pct - 1.0 : how much is the selected row near the target position
       */
      public virtual void render_match (Cairo.Context ctx, Match m, int width, int height, bool use_base = false, double selected_pct = 1.0)
      {
        ctx.translate (2, 2);
        this.draw_icon_in_position (ctx, m.icon_name, 32);
      }
      protected virtual int calculate_row_height ()
      {
        return 36;
      }
      /* End Methods to override - do not edit below */
      
      protected Utils.ColorHelper ch;
      
      protected Gtk.TextDirection rtl;
            
      protected void draw_icon_in_position (Cairo.Context ctx, string? name, int pixel_size, double with_alpha = 1.0)
      {
        ctx.rectangle (0, 0, pixel_size, pixel_size);
        ctx.clip ();
        if (name == null || name == "") name = "unknown";

        var icon_pixbuf = IconCacheService.get_default ().get_icon (name, pixel_size);
        if (icon_pixbuf == null) return;

        Gdk.cairo_set_source_pixbuf (ctx, icon_pixbuf, 0, 0);
        if (with_alpha == 1.0)
          ctx.paint ();
        else
          ctx.paint_with_alpha (with_alpha);
      }
      
      construct
      {
        rtl = Gtk.TextDirection.LTR;
        ch = new Utils.ColorHelper (this);
      }

      private int row_height_cached = 36;
      public int get_row_height_request ()
      {
        return this.row_height_cached;
      }

      public override void style_set (Style? previous_style)
      {
        // calculate here the new row height
        base.style_set (previous_style);
        this.rtl = this.get_direction ();
        Utils.update_layout_rtl (this.get_layout (), rtl);
        this.get_layout ().set_ellipsize (Pango.EllipsizeMode.END);
        this.row_height_cached = calculate_row_height ();
        this.queue_resize (); // queue_resize, so MatchListView will query for new row_height_request
      }

      public override bool expose_event (Gdk.EventExpose event) {
        //Transparent.
        return true;
      }
      
    }
    
    private MatchViewRendererBase renderer;
    private Utils.ColorHelper ch;
    public MatchListView (MatchViewRendererBase mr)
    {
      ch = new Utils.ColorHelper (this);
      inhibit_move = false;
      renderer = mr;
      // Add the renderer to screen as a child, this way it will receive all events.
      mr.show ();
      mr.set_parent (this);
      // Add our window to get mouse events
      this.above_child = false;
      this.visible_window = false;
      this.set_has_window (false);
      this.set_events (Gdk.EventMask.BUTTON_PRESS_MASK |
                       Gdk.EventMask.SCROLL_MASK);
      
      // D&D
      Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, {}, 
                               Gdk.DragAction.ASK | 
                               Gdk.DragAction.COPY | 
                               Gdk.DragAction.MOVE | 
                               Gdk.DragAction.LINK);

      //this.above_child = true;
      this.visible_window = false;
      this.offset = this.toffset = 0;
      this.soffset = this.tsoffset = 0;
      this.goto_index = 0;
      this.select_index = -1;
      this.row_height = renderer.get_row_height_request ();
      this.tid = 0;

      this.items = null;
      
      this.size_allocate.connect (this.update_target_offsets);
      this.notify["behavior"].connect (this.update_target_offsets);
      this.notify["min-visible-rows"].connect (this.queue_resize);
      this.notify["animation-enabled"].connect (()=>{
        this.update_current_offsets ();
      });
    }
    
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      if (b) callback (this.renderer);
    }
    
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      base.size_allocate (allocation);
      renderer.size_allocate ({ 0, 0, 0, 0 });
    }
    public override void size_request (out Requisition requisition)
    {
      base.size_request (out requisition);
      int tmp = this.renderer.get_row_height_request ();
      if (tmp != this.row_height)
      {
        this.row_height = tmp;
        this.update_target_offsets ();
        this.queue_draw ();
      }
      requisition.width = 1;
      requisition.height = this.row_height * this.min_visible_rows;
    }

    private bool _select (int i)
    {
      if (i == this.select_index ||
          this.items == null ||
          i < -1 ||
          i >= this.items.size) return false;
      this.select_index = i;
      return true;
    }
    
    private bool _goto (int i)
    {
      if (i == this.goto_index ||
          this.items == null ||
          i < 0 ||
          i >= this.items.size) return false;
      this.goto_index = i;
      return true;
    }
    
    private bool update_current_offsets ()
    {
      if (! (animation_enabled && this.is_realized ()) )
      {
        this.tid = 0;
        this.offset = this.toffset;
        this.soffset = this.tsoffset;
        this.queue_draw ();
        return false;
      }
      if (inhibit_move) return false;
      bool needs_animation = false;
      if (this.offset != this.toffset)
      {
        needs_animation = true;
        int inc = (int) Math.fabs (this.toffset - this.offset);
        if (inc < 4)
        {
          this.offset = this.toffset;
        }
        else
        {
          inc = int.max (1, inc >> 1);
          this.offset += this.toffset > this.offset ? inc : - inc;
        }
      }
      if (this.soffset != this.tsoffset && this.selection_enabled)
      {
        needs_animation = true;
        int inc = (int) Math.fabs (this.tsoffset - this.soffset);
        if (inc < 4)
        {
          this.soffset = this.tsoffset;
        }
        else
        {
          inc = int.max (1, inc >> 1);
          this.soffset += this.tsoffset > this.soffset ? inc : - inc;
        }
      }
      if (needs_animation)
      {
        if (tid == 0) tid = Timeout.add (ANIM_TIMEOUT, this.update_current_offsets);
        this.queue_draw ();
        return true;
      }

      tid = 0;
      return false;
    }
    
    private void update_target_offsets ()
    {
      int visible_items = this.allocation.height / this.row_height;
      
      switch (this.behavior)
      {
        case Behavior.TOP_FORCED:
          // Item has to stay on top
          this.toffset = this.row_height * this.goto_index;
          break;
        default:
        case Behavior.CENTER:
          if (this.goto_index <= (visible_items / 2) || this.items.size <= visible_items)
          {
            this.toffset = 0;
          }
          else if (this.goto_index >= ( this.items.size - 1 - (visible_items / 2) ))
          {
            this.toffset = this.row_height * this.items.size - this.allocation.height;
          }
          else
          {
            this.toffset = this.row_height * this.goto_index - this.allocation.height / 2 + this.row_height / 2;
          }
          break;
      }
      // update also selection
      this.tsoffset = this.select_index * this.row_height - this.toffset;
      update_current_offsets ();
    }
    
    public void set_list (Gee.List<Match>? list, int targetted_index = 0, int selected_index = -1)
    {
      this.items = list;
      this.select_index = selected_index;
      this.goto_index = targetted_index;
      inhibit_move = false;
      this.update_target_offsets ();
      this.queue_draw ();
    }
    
    public int get_list_size ()
    {
      return this.items == null ? 0 : this.items.size;
    }
    
    public override bool expose_event (Gdk.EventExpose event)
    {
      /* Clip */
      Cairo.Context ctx = Gdk.cairo_create (this.window);
      ctx.translate (this.allocation.x, this.allocation.y);
      ctx.rectangle (0, 0, this.allocation.width, this.allocation.height);
      ctx.clip ();
      ctx.set_operator (Cairo.Operator.OVER);
      
      if (this.use_base_colors)
      {
        ch.set_source_rgba (ctx, 1.0, ch.StyleType.BASE, Gtk.StateType.NORMAL);
        ctx.paint ();
      }
      
      if (this.items == null || this.items.size == 0) return true;

      ctx.set_font_options (this.get_screen().get_font_options());

      int visible_items = this.allocation.height / this.row_height + 2;
      int i = get_item_at_pos (0);
      visible_items += i;
      
      int ypos = 0;

      if (this.select_index >= 0 && this.selection_enabled)
      {
        if (this.soffset > (-this.row_height) && this.soffset < this.allocation.height)
        {
          bool had_focus = Gtk.WidgetFlags.HAS_FOCUS in this.get_flags ();
          // fool theme engine to use proper bg color
          if (!had_focus) this.set_flags (Gtk.WidgetFlags.HAS_FOCUS);
          ypos = int.max (this.soffset, 0) + this.allocation.y;
          event.area.x = this.allocation.x;
          event.area.width = this.allocation.width;
          Gtk.paint_flat_box (this.style, event.window, StateType.SELECTED,
                              ShadowType.NONE, event.area, this, "cell_odd",
                              this.allocation.x, ypos,
                              this.allocation.width, this.row_height);
          if (!had_focus) this.unset_flags (Gtk.WidgetFlags.HAS_FOCUS);
        }
      }
      double pct = 1.0;
      for (; i < visible_items && i < this.items.size; ++i)
      {
        ypos = i * this.row_height - this.offset;
        if (ypos > this.allocation.height) break;
        ctx.save ();
        ctx.translate (0, ypos);
        ctx.rectangle (0, 0, this.allocation.width, this.row_height);
        ctx.clip ();
        pct = 1.0;
        if (this.selection_enabled && i == select_index)
        {
          // set pct as 1.0 + [0.0 - 1.0] where second operator is the "near-factor"
          pct = (Math.fabs (this.toffset - this.offset) / this.row_height);
          if (pct == 0.0) pct = (Math.fabs (this.tsoffset - this.soffset) / this.row_height);
          pct = 2.0 - double.min (1.0 , pct);
        }
        renderer.render_match (ctx, this.items.get (i), this.allocation.width, this.row_height, this.use_base_colors, pct);
        ctx.restore ();
      }
      
      return true;
    }

    private int get_item_at_pos (int y)
    {
      return (this.offset + y) / this.row_height;
    }
    
    public override bool scroll_event (Gdk.EventScroll event)
    {
      if (this.items == null) return true;
      inhibit_move = false;
      int k = 1;
      if (event.direction == event.direction.UP) k = this.goto_index == 0 ? 0 : -1;

      this.set_indexes (this.goto_index + k, this.goto_index + k);
      this.selected_index_changed (this.select_index);
      return true;
    }
    
    // Fired when user changes selection interacting with the list
    public signal void selected_index_changed (int new_index);
    public signal void fire_item ();
    
    private int dragdrop_target_item = 0;
    private string dragdrop_name = "";
    private string dragdrop_uri = "";
    public override bool button_press_event (Gdk.EventButton event)
    {
      if (this.tid != 0) return true;
      this.dragdrop_target_item = get_item_at_pos ((int)event.y);
      var tl = new TargetList ({});
      
      if (this.items == null || this.items.size <= this.dragdrop_target_item)
      {
        dragdrop_name = "";
        dragdrop_uri = "";
        Gtk.drag_source_set_target_list (this, tl);
        Gtk.drag_source_set_icon_stock (this, Gtk.Stock.MISSING_IMAGE);
        return true;
      }
      
      if (this.selection_enabled)
      {
        if (event.type == event.type.2BUTTON_PRESS &&
            this.select_index == this.dragdrop_target_item)
        {
          this.set_indexes (this.dragdrop_target_item, this.dragdrop_target_item);
          this.fire_item ();
          return true; //Fire item! So we don't need to drag things! 
        }
        else
        {
          this.inhibit_move = true;
          this.set_indexes (this.dragdrop_target_item, this.dragdrop_target_item);
          this.selected_index_changed (this.select_index);
          Timeout.add (Gtk.Settings.get_default ().gtk_double_click_time ,()=>{
            if (inhibit_move)
            {
              inhibit_move = false;
              update_current_offsets ();
            }
            return false;
          });
        }
      }

      UriMatch? um = items.get (this.dragdrop_target_item) as UriMatch;
      if (um == null)
      {
        Gtk.drag_source_set_target_list (this, tl);
        Gtk.drag_source_set_icon_stock (this, Gtk.Stock.MISSING_IMAGE);
        dragdrop_name = "";
        dragdrop_uri = "";
        return true;
      }

      tl.add_text_targets (0);
      tl.add_uri_targets (1);
      dragdrop_name = um.title;
      dragdrop_uri = um.uri;
      Gtk.drag_source_set_target_list (this, tl);
      
      try {
        var icon = GLib.Icon.new_for_string (um.icon_name);
        if (icon == null) return true;

        Gtk.IconInfo iconinfo = Gtk.IconTheme.get_default ().lookup_by_gicon (icon, 48, Gtk.IconLookupFlags.FORCE_SIZE);
        if (iconinfo == null) return true;

        Gdk.Pixbuf icon_pixbuf = iconinfo.load_icon ();
        if (icon_pixbuf == null) return true;
        
        Gtk.drag_source_set_icon_pixbuf (this, icon_pixbuf);
      }
      catch (GLib.Error err) {}
      return true;
    }
    
    public override void drag_data_get (Gdk.DragContext context, SelectionData selection_data, uint info, uint time_)
    {
      /* Called at drop time */
      selection_data.set_text (dragdrop_name, -1);
      selection_data.set_uris ({dragdrop_uri});
    }
  }
  
  public class ResultBox: EventBox
  {
    private const int VISIBLE_RESULTS = 5;
    private const int ICON_SIZE = 36;
    private int mwidth;
    private int nrows;

    private VBox vbox;
    private HBox status_box;
    
    private Utils.ColorHelper ch;
    
    public ResultBox (int width, int nrows = 5)
    {
      this.mwidth = width;
      this.nrows = nrows;
      this.set_has_window (false);
      this.above_child = false;
      this.visible_window = false;
      ch = new Utils.ColorHelper (this);
      build_ui();
    }

		private MatchListView view;
		private MatchViewRenderer rend;
		private Label status;
		private Label logo;
		
		public new void set_state (Gtk.StateType state)
		{
		  base.set_state (state);
		  status.set_state (state);
		  logo.set_state (state);
		}
		
		public override bool expose_event (Gdk.EventExpose event)
		{
        var ctx = Gdk.cairo_create (this.get_window ());
        ctx.set_operator (Cairo.Operator.OVER);
        ctx.translate (this.allocation.x, status.allocation.y);
        ctx.rectangle (0, 0, this.allocation.width, status.allocation.height);
        ctx.clip ();
        /* Prepare bg's colors using GtkStyle */
        Pattern pat = new Pattern.linear(0, 0, 0, status.allocation.height);
        
        StateType t = this.get_state ();
        ch.add_color_stop_rgba (pat, 0.0, 0.95, ch.StyleType.BG, t);
        ch.add_color_stop_rgba (pat, 1.0, 0.95, ch.StyleType.BG, t, ch.Mod.DARKER);
        /* Prepare and draw top bg's rect */
        ctx.set_source (pat);
        ctx.paint ();

        /* Propagate Expose */               
        this.propagate_expose (this.get_child(), event);
        
        return true;
    }
    
    public MatchListView get_match_list_view ()
    {
      return this.view;
    }

    public override void size_request (out Requisition requisition)
    {
      vbox.size_request (out requisition);
      requisition.width = int.max (requisition.width, this.mwidth);
    }

    private void build_ui()
    {
      rend = new MatchViewRenderer ();
      view = new MatchListView (rend);
      view.min_visible_rows = this.nrows;
      
      vbox = new VBox (false, 0);
      vbox.border_width = 0;
      this.add (vbox);
      vbox.pack_start (view);
      status_box = new HBox (false, 0);
      status_box.set_size_request (-1, 15);
      vbox.pack_start (status_box, false);
      status = new Label (null);
      status.set_alignment (0, 0);
      status.set_markup (Markup.printf_escaped ("<b>%s</b>", _("No results.")));
      logo = new Label (null);
      logo.set_alignment (1, 0);
      logo.set_markup (Markup.printf_escaped ("<i>%s</i>", Config.RELEASE_NAME));
      status_box.pack_start (status, false, false, 10);
      status_box.pack_start (new Label (null), true, false);
      status_box.pack_start (logo, false, false, 10);
    }

    public void update_matches (Gee.List<Synapse.Match>? rs)
    {
      view.set_list (rs);
      if (rs==null || rs.size == 0)
        status.set_markup (Markup.printf_escaped ("<b>%s</b>", _("No results.")));
      else
        status.set_markup (Markup.printf_escaped (_("<b>1 of %d</b>"), view.get_list_size ()));
    }
    
    public void move_selection_to_index (int i)
    {
      view.set_indexes (i, i);
      status.set_markup (Markup.printf_escaped (_("<b>%d of %d</b>"), i + 1, view.get_list_size ()));
    }
  }
}
