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
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  /* Result List stuff */
  public class ResultBox: EventBox
  {
    private const int VISIBLE_RESULTS = 5;
    private const int ICON_SIZE = 35;
    private int mwidth;
    private int nrows;
    private bool no_results;
    
    public ResultBox (int width, int nrows = 5)
    {
      this.mwidth = width;
      this.nrows = nrows;
      no_results = true;
      build_ui();
    }
    
    private enum Column {
			IconColumn = 0,
			NameColumn = 1,
		}
		
		private TreeView view;
		ListStore results;
		private Label status;
		
		private bool on_expose (Widget w, Gdk.EventExpose event) {
        var ctx = Gdk.cairo_create (w.window);
        /* Clear Stage */
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.set_operator (Cairo.Operator.OVER);

        /* Prepare bg's colors using GtkStyle */
        Gtk.Style style = w.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Pattern pat = new Pattern.linear(0, 0, 0, w.allocation.height);
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        pat.add_color_stop_rgba (1.0 - 15.0 / w.allocation.height, double.min(r + 0.15, 1),
                                    double.min(g + 0.15, 1),
                                    double.min(b + 0.15, 1),
                                    0.95);
        pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                    double.max(g - 0.15, 0),
                                    double.max(b - 0.15, 0),
                                    0.95);
        /* Prepare and draw top bg's rect */
        ctx.rectangle (0, 0, w.allocation.width, w.allocation.height);
        ctx.set_source (pat);
        ctx.fill ();

        /* Propagate Expose */               
        Container c = (w is Container) ? (Container) w : null;
        if (c != null)
          c.propagate_expose (this.get_child(), event);
        
        return true;
    }
		
    private void build_ui()
    {
      var vbox = new VBox (false, 0);
      this.expose_event.connect (on_expose);
      vbox.border_width = 1;
      this.add (vbox);
      var resultsScrolledWindow = new ScrolledWindow (null, null);
      resultsScrolledWindow.set_policy (PolicyType.NEVER, PolicyType.NEVER);
      vbox.pack_start (resultsScrolledWindow);
      var status_box = new HBox (false, 0);
      status_box.set_size_request (-1, 15);
      vbox.pack_start (status_box, false);
      status = new Label (null);
      status.set_alignment (0, 0);
      status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
      var logo = new Label (null);
      logo.set_alignment (1, 0);
      logo.set_markup (Markup.printf_escaped ("<i>Sezen 2 </i>"));
      status_box.pack_start (status, false, false, 10);
      status_box.pack_start (new Label (null), true, false);
      status_box.pack_start (logo, false, false, 10);
      
      view = new TreeView ();
			view.enable_search = false;
			view.headers_visible = false;
			// If this is not set the tree will call IconDataFunc for all rows to 
			// determine the total height of the tree
			view.fixed_height_mode = true;
			resultsScrolledWindow.add (view);
			view.show();
      // Model
      view.model = results = new ListStore(2, typeof(GLib.Icon), typeof(string));

      var column = new TreeViewColumn ();
			column.sizing = Gtk.TreeViewColumnSizing.FIXED;

			var crp = new CellRendererPixbuf ();
      crp.set_fixed_size (ICON_SIZE, ICON_SIZE);
      crp.stock_size = IconSize.DND;
			column.pack_start (crp, false);
			column.add_attribute (crp, "gicon", (int) Column.IconColumn);
			
			var ctxt = new CellRendererText ();
			ctxt.ellipsize = Pango.EllipsizeMode.END;
			ctxt.set_fixed_size (mwidth - ICON_SIZE, ICON_SIZE);
			column.pack_start (ctxt, false);
      column.add_attribute (ctxt, "markup", (int) Column.NameColumn);
      
      view.append_column (column);
      
      Requisition requisition = {0, 0};
      status_box.size_request (out requisition);
      requisition.width = mwidth;
      requisition.height += nrows * (ICON_SIZE + 4) + 2;
      vbox.set_size_request (requisition.width, requisition.height); 
    }

    public void update_matches (Gee.List<Sezen.Match>? rs)
    {
      results.clear();
      if (rs==null)
      {
        no_results = true;
        status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
        return;
      }
      no_results = false;
      string desc;
      TreeIter iter;
      GLib.Icon icon = null;
      foreach (Match m in rs)
      {
        results.append (out iter);
        desc = Utils.replace_home_path_with (m.description, "Home > "); // FIXME: i18n
        try {
          icon = GLib.Icon.new_for_string(m.icon_name);
        } catch (GLib.Error err) { icon = null; }
        results.set (iter, Column.IconColumn, icon, Column.NameColumn, 
                     Markup.printf_escaped ("<span><b>%s</b></span>\n<span size=\"small\">%s</span>",m.title, desc));
      }
      var sel = view.get_selection ();
      sel.select_path (new TreePath.first());
      status.set_markup (Markup.printf_escaped ("<b>1 of %d</b>", results.length));
    }
    public void move_selection_to_index (int i)
    {
      var sel = view.get_selection ();
      Gtk.TreePath path = new TreePath.from_string( i.to_string() );
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      status.set_markup (Markup.printf_escaped ("<b>%d of %d</b>", i + 1, results.length));
    }
    public int move_selection (int val, out int old_index)
    {
      if (no_results)
        return -1;
      var sel = view.get_selection ();
      int index = -1, oindex = -1;
      GLib.List<TreePath> sel_paths = sel.get_selected_rows(null);
      TreePath path = sel_paths.first ().data;
      TreePath opath = path;
      oindex = path.to_string().to_int();
      old_index = oindex;
      if (val == 0)
        return oindex;
      if (val > 0)
        path.next ();
      else if (val < 0)
        path.prev ();
      
      index = path.to_string().to_int();
      if (index < 0 || index >= results.length)
      {
        index = oindex;
        path = opath;
      }
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      
      return index;
    }
  }


  public class ContainerOverlayed: Gtk.Container
  {
    private Widget widgets[5];
    private float scale[5];

    public enum Position
    {
      MAIN,
      TOP_LEFT,
      TOP_RIGHT,
      BOTTOM_RIGHT,
      BOTTOM_LEFT
    }

    public ContainerOverlayed ()
    {
      scale = {0, 0.5f, 0.5f, 0.5f, 0.5f};
      widgets = {null, null, null, null, null};
      set_has_window(false);
      set_redraw_on_allocate(false);
    }
    public void set_scale_for_pos (float s, Position pos)
    {
      if (pos == Position.MAIN)
        return;
      if (s != scale[pos])
      {
        scale[pos] = float.max (0.0f, float.min (0.5f, s));
        this.queue_resize ();
      }
    }
    public override void size_request (out Requisition requisition)
    {
      if (widgets[Position.MAIN] != null)
      {
        widgets[Position.MAIN].size_request (out requisition);
        return;
      }
      Requisition req = {0, 0};
      for (int i = 1; i < 5; ++i)
      {
        if (widgets[i] != null)
        {
          widgets[i].size_request (out req);
          requisition.width = int.max (requisition.width, req.width);
          requisition.height = int.max (requisition.height, req.height);
        }
      }
    }
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);    
      if (widgets[Position.MAIN] != null)
      {
        widgets[Position.MAIN].size_allocate (allocation);
      }
      if (widgets[Position.TOP_LEFT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.TOP_LEFT]);
        allocation.height = (int)(alloc.height * scale[Position.TOP_LEFT]);
        widgets[Position.TOP_LEFT].size_allocate (allocation);
      }
      if (widgets[Position.TOP_RIGHT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.TOP_RIGHT]);
        allocation.height = (int)(alloc.height * scale[Position.TOP_RIGHT]);
        allocation.x = alloc.x + alloc.width - allocation.width;
        widgets[Position.TOP_RIGHT].size_allocate (allocation);
      }
      if (widgets[Position.BOTTOM_RIGHT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.BOTTOM_RIGHT]);
        allocation.height = (int)(alloc.height * scale[Position.BOTTOM_RIGHT]);
        allocation.x = alloc.x + alloc.width - allocation.width;
        allocation.y = alloc.y + alloc.height - allocation.height;
        widgets[Position.BOTTOM_RIGHT].size_allocate (allocation);
      }
      if (widgets[Position.BOTTOM_LEFT] != null)
      {
        allocation.width = (int)(alloc.width * scale[Position.BOTTOM_LEFT]);
        allocation.height = (int)(alloc.height * scale[Position.BOTTOM_LEFT]);
        allocation.x = alloc.x;
        allocation.y = alloc.y + alloc.height - allocation.height;
        widgets[Position.BOTTOM_LEFT].size_allocate (allocation);
      }
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      for (int i = 0; i < 5; ++i)
      {
        if (widgets[i] != null)
          callback (widgets[i]);
      }
    }
    public void set_widget_in_position (Widget widget, Position pos)
    {
      if (widgets[pos] != null)
        widgets[pos].unparent ();
      widgets[pos] = widget;
      if (widget != null)
        widget.set_parent (this);
    }
    public void swapif (Widget w, Position pos1, Position pos2)
    {
      if (widgets[pos1] == w)
        swap (pos1, pos2);
    }
    public void swap (Position pos1, Position pos2)
    {
      Widget t = widgets[pos1];
      widgets[pos1] = widgets[pos2];
      widgets[pos2] = t;
    }

    public override void add (Widget widget)
    {
      //TODO
    }
    public override void remove (Widget widget)
    {
      //TODO
    }
  }
  
  /* HSelectionContainer */
  public class HSelectionContainer: Gtk.Container
  {
    public delegate void SelectWidget (Widget w, bool select);
    private ArrayList<Widget> childs;
    
    private SelectWidget func;
    private int padding;
    private int selection = 0;
    private int[] allocations = {};
    private bool[] visibles = {};
    private bool direction = true;
    private HSeparator sep;
    
    public enum SelectionAlign
    {
      LEFT = 0,
      CENTER = 1,
      RIGHT = 2
    }
    private int align;
    
    
    public HSelectionContainer (SelectWidget? func, int padding)
    {
      this.func = func;
      this.padding = padding;
      this.align = SelectionAlign.CENTER;
      childs = new ArrayList<Widget>();
      set_has_window(false);
      set_redraw_on_allocate(false);
      sep = new HSeparator();
      sep.set_parent (this);
      sep.show ();
    }
    
    public void set_separator_visible (bool b)
    {
      sep.set_visible (b);
      this.queue_resize ();
    }
    
    public void set_selection_align (SelectionAlign align)
    {
      this.align = align;
    }
    
    public void select_next_circular ()
    {
      int sel = selection;
      sel += direction ? 1 : -1;
      if (sel < 0)
      {
        sel = 1;
        direction = true;
      }
      else if (sel >= childs.size)
      {
        sel = childs.size - 2;
        direction = false;
      }
      select (sel);
    }
    public void select_next () {select(selection+1);}
    public void select_prev () {select(selection-1);}
    
    public void select (int index)
    {
      if (index < 0 || childs.size <= index)
        return;
      
      if (func != null)
      {
        func (childs.get(selection), false);
        func (childs.get(index), true);
      }
      this.selection = index;
      this.queue_resize();
      foreach (Widget w in childs)
        w.queue_draw();
    }
    
    public int get_selected ()
    {
      return selection;
    }
    
    public override void size_request (out Requisition requisition)
    {
      Requisition req = {0, 0};
      requisition.width = 1;
      requisition.height = 1;
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
      requisition.height += 1;
      if (sep.visible)
        requisition.height += 3;
    }

    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
      int lastx = 0;
      Requisition req = {0, 0};
      int i = 0;
      // update relative coords
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        this.allocations[i] = lastx;
        lastx += padding + req.width;
        ++i;
      }
      int offset = 0;
      switch (this.align)
      {
        case SelectionAlign.LEFT:
          offset = - allocations[selection];
          break;
        case SelectionAlign.RIGHT:
          offset = allocation.width - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width;
          break;
        default:
          offset = allocation.width / 2 - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width / 2;
          break;
      }
      // update widget allocations and visibility
      i = 0;
      int pos = 0;
      int sep_space = sep.visible ? 4 : 1;
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        pos = offset + allocations[i];
        if (pos < 0 || pos + req.width > alloc.width)
        {
          visibles[i] = false;
          w.hide ();
        }
        else
        {
          visibles[i] = true;
          allocation.x = alloc.x + pos;
          allocation.width = req.width;
          allocation.height = req.height;
          allocation.y = alloc.y + (alloc.height - sep_space - req.height) / 2;
          w.size_allocate (allocation);
          w.show_all ();
        }
        ++i;
      }
      allocation.x = alloc.x;
      allocation.y = alloc.y + alloc.height - 3;
      allocation.height = 2;
      allocation.width = alloc.width;
      sep.size_allocate (allocation);
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      int i = 0;
      if (b)
      {
        callback (sep);
      }
      if (childs.size == 0)
        return;
      if (this.align == SelectionAlign.LEFT)
      {
        for (i = childs.size - 1; i >= 0; ++i)
        {
          if ( visibles[i] )
            callback (childs.get(i));
        }
      }
      else if (this.align == SelectionAlign.RIGHT)
      {
        foreach (Widget w in childs)
        {
          if ( visibles[i] )
            callback (w);
          ++i;
        }
      }
      else //align center
      {
        int j;
        j = i = selection;
        ArrayList<Widget> reordered = new ArrayList<Widget>();
        reordered.add (childs.get(i));
        while (j >= 0 || i < childs.size)
        {
          --j;
          ++i;
          if (j >= 0)
            reordered.add (childs.get(j));
          if (i < childs.size)
            reordered.add (childs.get(i));
        }
        for (i = reordered.size - 1; i >= 0; --i)
          callback (reordered.get(i));
      }
    }

    public override void add (Widget widget)
    {
      childs.add (widget);
      widget.set_parent (this);
      this.allocations += 0;
      this.visibles += true;
      if (childs.size==1)
      {
        this.selection = 0;
        if (func != null)
          func (widget, true);
      }
      else if (func != null)      
        func (widget, false);
    }
    
    public override void remove (Widget widget)
    {
      if (childs.remove (widget))
      {
        widget.unparent ();
        this.allocations.resize (this.allocations.length);
        this.visibles.resize (this.visibles.length);
      }
    }
  }
  public class Throbber: Label
  {
    private int step;
    private bool animate;
    private const int TIMEOUT = 1000 / 30;
    private const int MAX_STEP = 30;
    construct
    {
      step = 0;
      animate = false;
    }
    
    public bool is_animating ()
    {
      return animate;
    }

    public void start ()
    {
      if (animate)
        return;
      animate = true;
      Timeout.add (TIMEOUT, () => {
        step = (step + 1) % MAX_STEP;
        this.queue_draw ();
        return animate;
      } );
    }
    
    public void stop ()
    {
      if (!animate)
        return;
      animate = false;
    }
    public override bool expose_event (Gdk.EventExpose event)
    {
      if (animate)
      {
        var ctx = Gdk.cairo_create (this.window);
        ctx.translate (0.5, 0.5);
        ctx.set_operator (Cairo.Operator.OVER);
        Gtk.Style style = this.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.SELECTED], &r, &g, &b);
        double xc = this.allocation.x + this.allocation.width / 2;
        double yc = this.allocation.y + this.allocation.height / 2;
        double rad = int.min (this.allocation.width, this.allocation.height) / 2 - 0.5;
        var pat = new Cairo.Pattern.radial (xc, yc, 0, xc, yc, rad);
        pat.add_color_stop_rgba (0.5, r, g, b, 0);
        pat.add_color_stop_rgba (0.7, r, g, b, 1.0);
        Utils.rgb_invert_color (out r, out g, out b);
        pat.add_color_stop_rgba (1.0, r, g, b, 1.0);
        double gamma = Math.PI * 2.0 * step / MAX_STEP;
        ctx.new_path ();
        ctx.arc (xc, yc, rad, gamma, gamma + Math.PI * 2 / 3);
        ctx.line_to (xc, yc);
        ctx.close_path ();
        ctx.clip ();
        ctx.set_source (pat);
        ctx.paint ();
        base.expose_event (event);
      }
      return true;
    }
  }
  public class NamedIcon: Gtk.Image
  {
    public string not_found_name {get; set; default = "missing-image";}
    private string current;
    public NamedIcon ()
    {
      current = "";
    }
    public new void clear ()
    {
      current = "";
      base.clear ();
    }
    public void set_icon_name (string name, IconSize size)
    {
      if (name == current)
        return;
      else
      {
        if (name == "")
        {
          this.clear ();
          return;
        }
        try
        {
          this.set_from_gicon (GLib.Icon.new_for_string (name), size);
          current = name;
        }
        catch (Error err)
        {
          if (current != not_found_name)
          {
            if (not_found_name == "")
              this.clear ();
            else
              this.set_from_icon_name (not_found_name, IconSize.DIALOG);
            current = not_found_name;
          }
        }
      }
    }
  }
  public class FakeInput: Label
  {
    public override bool expose_event (Gdk.EventExpose event)
    {
      var ctx = Gdk.cairo_create (this.window);
      ctx.translate (0.5, 0.5);
      ctx.set_operator (Cairo.Operator.OVER);
      ctx.set_line_width (1.25);
      Gtk.Style style = this.get_style();
      double r = 0.0, g = 0.0, b = 0.0;
      Utils.gdk_color_to_rgb (style.fg[Gtk.StateType.NORMAL], &r, &g, &b);
      Utils.cairo_rounded_rect (ctx,
                                this.allocation.x,
                                this.allocation.y,
                                this.allocation.width - 0.5,
                                this.allocation.height - 0.5,
                                int.min(this.xpad, this.ypad));
      Utils.rgb_invert_color (out r, out g, out b);
      ctx.set_source_rgba (r, g, b, 1.0);
      Cairo.Path path = ctx.copy_path ();
      ctx.save ();
      ctx.clip ();
      ctx.paint ();
      Utils.rgb_invert_color (out r, out g, out b);
      var pat = new Cairo.Pattern.linear (0, this.allocation.y, 0, this.allocation.y + 2 * this.ypad);
      pat.add_color_stop_rgba (0, r, g, b, 0.6);
      pat.add_color_stop_rgba (0.3, r, g, b, 0.25);
      pat.add_color_stop_rgba (1.0, r, g, b, 0);
      ctx.set_source (pat);
      ctx.paint ();
      ctx.restore ();
      ctx.append_path (path);
      ctx.set_source_rgba (r, g, b, 0.6);
      ctx.stroke ();
      return base.expose_event (event);
    }
  }
}
