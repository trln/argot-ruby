# frozen_string_literal: true

describe Argot::Flattener do

  subject { Argot::Flattener.new }

  let (:expected_included_author) do
    ["Saint-Saëns, Camille, 1835-1921.",
     "Schwenkel, Christina.",
     "Ferrini, Vincent, 1913-2007.",
     "Plotinus.",
     "Name, Author, (Test name), 1944-.",
     "Kungliga Biblioteket (Sweden).",
     "United States. Congress (94th, 2nd session : 1976).",
     "North Carolina. Building Code Council.",
     "Germany (East).",
     "Café Tacuba (Musical group)",
     "Great Central Fair for the U.S. Sanitary Commission (1864 : Philadelphia, Pa.). "\
     "Committee on Public Charities and Benevolent Institutions.",
     "Deutsch Foundation Conference (1930 : University of Chicago).",
     "Masson, VeNeta.",
     "Masson, VeNeta."]
  end


  context 'work_entry' do
    @record = flatten_test_record('argot-included-work-flattener.json', 
      {'included_work' => {'flattener' => 'work_entry'}})
    @expectations = load_expectations('flattener/work_entry_expectations', @record)

    @expectations.each do |record, field, ev|
      it "converts #{field} correctly" do
        expect(record).to have_key(field)
        expect(record[field]).to eq(ev)
      end  
    end
  end

    
    
  context 'misc_id' do
    @record = flatten_test_record('argot-misc-id-flattener.json', 
        {'included_work' => {'flattener' => 'misc_id'}})
      
    load_expectations('flattener/misc_id_expectations', @record).each do |record, field, ev|
      it "converts #{field} correctly" do
        expect(record).to have_key(field)
        expect(record[field]).to eq(ev)  
      end
    end
  end 

  context 'notes' do 
    @rec = flatten_test_record('argot-note-flattener.json',
                    { 'note_performer_credits' => { 'flattener' => 'note' }})
    @expectations = load_expectations('flattener/notes_expectations', @rec)
    
    
    @expectations.each do |record, field, ev| 
      it "converts #{field} correctly" do
        expect(record).to have_key(field)
        expect(record[field]).to eq(ev)
      end
    end
  end

  context 'title_variant' do
    config = 
    @rec = flatten_test_record('argot-title-variant-flattener.json', {'title_variant' => {'flattener' => 'title_variant'}})
    load_expectations('flattener/title_variant_expectations', @rec).each do |record, field, ev|
       it "converts #{field} correctly" do
        expect(record).to have_key(field)
        expect(record[field]).to eq(ev)
      end
    end
  end

  context 'physical description' do
    @rec = flatten_test_record('argot-indexed-value-flattener.json', 
       {'physical_description' => {'flattener' => 'indexed_value'}})
    load_expectations('flattener/physical_description_expectations', @rec).each do |record, field, ev|
       it "converts #{field} correctly" do
        expect(record).to have_key(field)
        expect(record[field]).to eq(ev)
      end
    end
  end
end
