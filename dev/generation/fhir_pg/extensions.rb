module FhirPg
  module Extensions
    def dt
      FhirPg::Datatypes
    end

    def mk_db(xml, resources_db, types_db)
      db = resources_db.dup
      defn(xml).each do |n|
        path = el_path(n)
        context = find_context(db, path.map{ |p| [p, :attrs] }.flatten)
        (context[:extension] ||= {}).tap do |ex|
          ex[:name] ||= :extension
          ex[:kind] ||= :extension
          ex[:type] ||= :extension
          ex[:collection] ||= true
          ex[:required] ||= false
          ex[:path] ||= (path + [:extension]).map(&:to_s).join('.')
          (ex[:attrs] ||= {}).tap do |attrs|
            name = el_name(n)
            (attrs[name] ||= {}).tap do |d|
              d[:path] = (path + [:extension, name]).map(&:to_s).join('.')
              d[:collection] = el_collection?(n)
              d[:required] = el_required?(n)
              type = n.xpath('./definition/type/code').first[:value].underscore.to_sym
              d.merge!(dt.mount(types_db, d[:path], type))
            end
          end
        end
      end
      db
    end

    def uniform(obj)
      obj.each do |key, value|
        if key.to_s == 'extension'
          ext = {}
          value.each do |e|
            e_key = e['url'].split("#").last.underscore
            e_value = e.select{|x, y| x.start_with?('value')}.first
            if e_value.present?
              ext[e_key] = e_value.last
            end
          end
          value.clear
          value << ext
        end
        if value.is_a?(Array)
          value.each do |v|
            if v.is_a?(Hash)
              uniform(v)
            end
          end
        elsif value.is_a?(Hash)
          uniform(value)
        end
      end
    end

    def expand(obj, url)
      obj.each do |key, value|
        if key.to_s == 'extension'
          arr = []
          e = value.first
          if e
            e.each do |k, v|
              arr << {
                'url' => "#{url}\##{k}",
                'value' => v
              }
            end
          end
          value.clear
          arr.each do |a|
            value << a
          end
        end
        if value.is_a?(Array)
          value.each do |v|
            if v.is_a?(Hash)
              expand(v, url)
            end
          end
        elsif value.is_a?(Hash)
          expand(value, url)
        end
      end
    end

    private

    def defn(x)
      x.xpath('.//extensionDefn')
    end

    def find_context(context, path)
      (path.size > 0) && find_context(context[path.first], path.last(path.size - 1)) || context
    end

    def el_attr(el, attr)
      el.xpath("./definition/#{attr}").first[:value]
    end

    def el_collection?(el)
      el_attr(el, 'max') == '*'
    end

    def el_required?(el)
      el_attr(el, 'min') == '1'
    end

    def el_name(n)
      nn(n.xpath('./code').first[:value])
    end

    def el_type(el)
      el.xpath('./contextType').first[:value].to_sym
    end

    def el_path(el)
      pt(el.xpath('./context').first[:value])
    end

    def nn(s)
      s.to_s.underscore.to_sym
    end

    def pt(s)
      s.split('.').map{|p|nn(p)}
    end

    extend self
  end
end
