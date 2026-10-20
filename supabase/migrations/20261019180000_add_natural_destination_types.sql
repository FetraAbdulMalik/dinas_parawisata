update public.destinations
set category = case name
  when 'Situ Cangkuang' then 'Danau'
  when 'Kawah Talaga Bodas' then 'Kawah'
  when 'Gunung Papandayan' then 'Gunung'
  when 'Situ Bagendit' then 'Danau'
  when 'Pantai Santolo' then 'Laut'
  else category
end
where category = 'Alam'
  and name in (
    'Situ Cangkuang',
    'Kawah Talaga Bodas',
    'Gunung Papandayan',
    'Situ Bagendit',
    'Pantai Santolo'
  );

notify pgrst, 'reload schema';
