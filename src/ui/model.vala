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

namespace Synapse.Gui
{
  public class Model : IModel, Object
  {
    /* Search strings */
    protected string[] _query = new string[SearchingFor.COUNT];
    public string[] query { get {return _query;} }
    
    /* Result Sets */
    protected Gee.List<Match>[] _results = new Gee.List<Match>[SearchingFor.COUNT];
    public Gee.List<Match>[] results { get {return _results;} }

    /* Focus */
    protected Entry<int, Match>[] _focus = new Entry<int, Match>[SearchingFor.COUNT];
    public Entry<int, Match>[] focus { get {return _focus;} }
      
    /* Multiple Selection :: maybe in the future */
    //public Gee.Map<int, Match> selected_sources {get; set;}
    //public Gee.Map<int, Match> selected_targets {get; set;}
    
    /* Category */
    public int selected_category {get; set;}
    
    /* SearchingFor */
    public SearchingFor searching_for {get; set; default = SearchingFor.SOURCES;}
    
    /* returns results[searching_for] != null && .size > 0 */
    public bool has_results ()
    {
      return _results[searching_for] != null && _results[searching_for].size > 0;
    }
    
    public Entry<int, Match> get_actual_focus ()
    {
      return _focus[searching_for];
    }
    
    public void set_actual_focus (int i)
    {
      _focus[searching_for].key = i;
      _focus[searching_for].value = _results[searching_for].get (i);
    }
    
    public void clear (int default_category = -1)
    {
      searching_for = SearchingFor.SOURCES;
      for (int i = 0; i < SearchingFor.COUNT; i++)
      {
        _focus[i].key = 0;
        _focus[i].value = null;
        _results[i] = null;
        _query[i] = "";
      }
      if (default_category >= 0)
        selected_category = default_category;
    }
    
    public void clear_searching_for (SearchingFor i)
    {
      // Synapse.Utils.Logger.log (this, "CLEAR: %u", i);
      _focus[i].key = 0;
      _focus[i].value = null;
      _results[i] = null;
      _query[i] = "";
    }
    
    construct
    {
      for (int i = 0; i < SearchingFor.COUNT; i++)
      {
        _focus[i] = new Entry<int, Match> ();
      }
      clear ();
    }
  }
}
