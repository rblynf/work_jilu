  class CSVData

    # 获取CSVDate对象
    # @param [String] file
    # @return [CSVData]
    # @sicne 0.0.1
    def self.find(file)
      file2 = File.file?(file) ?  file : File.join(__dir__, 'data', "#{file}.csv")
      # ObjectSpace.each_object(self){|csv|
      #   if csv.file == file2
      #     return csv
      #   end
      # }
      self.new(file2)
    end

    attr_reader(:file)

    def initialize(file)
      @file = file
      @handle = []
      @data = []
      IO.readlines(@file).each_with_index{|line, i|
        begin 
          line = line.delete("\n")
          array = line.split(',')

        rescue  Exception=> e
          if e.message.include?("UTF-8")
              line = line.force_encoding("gbk").delete("\n")
              array = line.force_encoding("gbk").split(',')
          end 
        end 
        next if array.all?{|a| a == '' }
        if i == 0
          @handle = array
        else
          @data << array
        end
      }
    end

    def row(row)
      @data.each{|a|
        if a[0] == row
          hash = {}
          @handle.each_with_index{|h, i|
            hash[h] = a[i]
          }
          return hash
        end
      }
      nil
    end

    #读所有data
    def all_row
        @data
    end 

    def handle
      @handle
    end 
  end# class CSVData



# file = CSVData.find('公称直径与不同类型水管对应的内径表')
# dataList = file.all_row
# p "dataList"
# p dataList
