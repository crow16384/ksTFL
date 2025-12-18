## TODO:
## - .tfl_serialize_spec(): validate spec against schema and export it as JSON file
##   -- used internally by tfl_write() and tfl_save()
##   -- need to add logic to combine styles (last win or deep merge?). 
##         When styleRef is provided as a vector of style names, need to combine them into single style definition (name can be a hash of the combined style names to ensure uniqueness - need to think of the logic)
##   -- need to validate that styles referenced across spec are defined in styles section
## - tfl_write(): internally call .tfl_serialize_spec() to write spec and serialize reference data frames to files + invove the python renderer
## - tfl_save(): user-facing function to save spec and data frames to files without rendering
## - tfl_render_saved(): takes a list of saved spec files combines them into sinle spec and invokes the python renderer to produce the final single output document
NULL

