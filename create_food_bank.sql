-- 1. Crear tabla 'default_meals'
create table if not exists default_meals (
  id uuid default gen_random_uuid() primary key,
  meal_title text not null,
  meal_description text,
  calories int,
  macros jsonb, -- {p: float, c: float, f: float}
  image_url text,
  time_of_day text, -- 'breakfast', 'lunch', 'dinner', 'snack'
  created_at timestamp with time zone default now()
);

-- 2. Habilitar RLS (Seguridad)
alter table default_meals enable row level security;

-- Permitir lectura pública de default_meals (Cualquier usuario autenticado puede leer)
create policy "Meals are viewable by everyone" 
  on default_meals for select 
  using ( auth.role() = 'authenticated' );

-- (Opcional) Solo admins pueden insertar/editar (ajustar según tu lógica de roles)
-- create policy "Only admins can insert meals" ...

-- 3. Insertar Datos Semilla (Seed Data)

-- BLOQUE 1: DESAYUNOS (Day 1-7)
insert into default_meals (meal_title, meal_description, calories, macros, image_url, time_of_day) values
('Avena Overnight Pro', '50g de avena integral, 1 scoop de proteína de suero, 100g de arándanos, 10g de semillas de chía, 200ml de leche de almendras.', 420, '{"p": 32, "c": 55, "f": 8}', 'https://cdn.fitnessapp.com/breakfast/avena_pro.jpg', 'breakfast'),
('Omelette Fitness', '3 claras de huevo, 1 huevo entero, 50g de espinacas, 30g de queso panela, 1 rebanada de pan integral tostado.', 310, '{"p": 25, "c": 18, "f": 15}', 'https://cdn.fitnessapp.com/breakfast/omelette.jpg', 'breakfast'),
('Pancakes de Plátano', '1 plátano maduro, 2 claras de huevo, 30g de harina de avena, canela y 10g de mantequilla de cacahuete.', 350, '{"p": 15, "c": 45, "f": 12}', 'https://cdn.fitnessapp.com/breakfast/pancakes.jpg', 'breakfast'),
('Tostadas con Aguacate', '2 rebanadas de pan de masa madre, 80g de aguacate, 2 huevos escalfados y una pizca de chile en hojuelas.', 450, '{"p": 20, "c": 40, "f": 22}', 'https://cdn.fitnessapp.com/breakfast/tostadas_avocado.jpg', 'breakfast'),
('Bowl de Yogur Griego', '200g de yogur griego sin azúcar, 30g de nueces de la India, 1 manzana verde picada y 5g de miel de abeja.', 380, '{"p": 22, "c": 35, "f": 18}', 'https://cdn.fitnessapp.com/breakfast/yogurt_bowl.jpg', 'breakfast');

-- BLOQUE 1: ALMUERZOS
insert into default_meals (meal_title, meal_description, calories, macros, image_url, time_of_day) values
('Pollo con Arroz Clásico', '200g de pechuga de pollo a la plancha, 60g de arroz integral (pesado en seco), 1/2 aguacate, 2 tortillas de maíz.', 560, '{"p": 50, "c": 55, "f": 16}', 'https://cdn.fitnessapp.com/lunch/pollo_arroz.jpg', 'lunch'),
('Salmón y Quinoa', '150g de filete de salmón, 1/2 taza de quinoa cocida, 150g de espárragos al grill, 1 cdita de aceite de oliva.', 490, '{"p": 35, "c": 30, "f": 25}', 'https://cdn.fitnessapp.com/lunch/salmon_quinoa.jpg', 'lunch'),
('Bowl de Ternera y Batata', '150g de bistec magro, 150g de batata (camote) al horno, ensalada mixta (lechuga, tomate, pepino) con limón.', 430, '{"p": 38, "c": 42, "f": 12}', 'https://cdn.fitnessapp.com/lunch/beef_sweetpotato.jpg', 'lunch'),
('Pasta Integral con Atún', '80g de pasta integral (seco), 1 lata de atún en agua, salsa de tomate casera, aceitunas verdes y orégano.', 480, '{"p": 30, "c": 65, "f": 10}', 'https://cdn.fitnessapp.com/lunch/tuna_pasta.jpg', 'lunch'),
('Tacos de Pavo y Frijoles', '120g de pavo molido, 1/2 taza de frijoles negros, 3 tortillas de maíz, pico de gallo y cilantro fresco.', 410, '{"p": 28, "c": 50, "f": 9}', 'https://cdn.fitnessapp.com/lunch/turkey_tacos.jpg', 'lunch');

-- BLOQUE 1: CENAS
insert into default_meals (meal_title, meal_description, calories, macros, image_url, time_of_day) values
('Pescado Blanco al Limón', '180g de tilapia o merluza, puré de calabacín (zucchini), 1/2 taza de arroz blanco, ensalada de espinacas.', 350, '{"p": 40, "c": 35, "f": 6}', 'https://cdn.fitnessapp.com/dinner/fish_lemon.jpg', 'dinner'),
('Pollo al Curry con Verduras', '150g de dados de pollo, mix de verduras (brócoli, pimiento, cebolla), 1/4 taza de leche de coco light, curry.', 380, '{"p": 35, "c": 15, "f": 18}', 'https://cdn.fitnessapp.com/dinner/chicken_curry.jpg', 'dinner'),
('Tofu Marinado y Ensalada', '200g de tofu firme marinado en soya, 1/2 taza de edamames, ensalada de col morada con semillas de sésamo.', 320, '{"p": 22, "c": 20, "f": 16}', 'https://cdn.fitnessapp.com/dinner/tofu_salad.jpg', 'dinner'),
('Enchiladas de Pollo Fit', '2 tortillas de maíz, 100g de pollo deshebrado, salsa verde natural (sin aceite), 30g de queso cottage.', 340, '{"p": 28, "c": 35, "f": 10}', 'https://cdn.fitnessapp.com/dinner/enchiladas_fit.jpg', 'dinner'),
('Brochetas de Pavo', '150g de pechuga de pavo en cubos, pimientos y cebolla en brocheta, 100g de papa cocida al vapor.', 310, '{"p": 32, "c": 30, "f": 7}', 'https://cdn.fitnessapp.com/dinner/turkey_skewers.jpg', 'dinner');

-- BLOQUE 2: DESAYUNOS
insert into default_meals (meal_title, meal_description, calories, macros, image_url, time_of_day) values
('Gachas de Centeno y Chía', '50g de centeno en hojuelas, 10g de chía, 1 taza de leche descremada, 1/2 pera y canela.', 330, '{"p": 14, "c": 52, "f": 6}', null, 'breakfast'),
('Tostada de Requesón y Miel', '2 rebanadas de pan de centeno, 100g de requesón bajo en grasa, 10g de nueces y 5g de miel.', 360, '{"p": 18, "c": 45, "f": 11}', null, 'breakfast'),
('Batido Energético de Dátiles', '1 scoop proteína, 2 dátiles, 30g avena, 1 tza agua de coco, 1 cdita mantequilla almendra.', 410, '{"p": 28, "c": 48, "f": 13}', null, 'breakfast'),
('Huevos con Champiñones', '2 huevos enteros, 100g de champiñones laminados, 1/4 cebolla blanca, 1 rebanada pan integral.', 320, '{"p": 19, "c": 22, "f": 17}', null, 'breakfast'),
('Muffin de Huevo y Verduras', '2 muffins caseros hechos con huevo, pimientos, espinaca y jamón de pavo. 1 naranja mediana.', 290, '{"p": 22, "c": 18, "f": 14}', null, 'breakfast'),
('Burrito de Desayuno Fit', '1 tortilla de harina integral, 2 claras de huevo, 1/4 taza frijoles refritos sin grasa, salsa roja.', 340, '{"p": 20, "c": 40, "f": 11}', null, 'breakfast'),
('Smoothie Bowl de Acai', '100g pulpa acai, 1/2 taza fresas, 10g coco rallado, 20g granola sin azúcar, 1 scoop proteína.', 390, '{"p": 25, "c": 42, "f": 14}', null, 'breakfast');

-- BLOQUE 2: ALMUERZOS
insert into default_meals (meal_title, meal_description, calories, macros, image_url, time_of_day) values
('Lentejas con Arroz Integral', '1 taza de lentejas cocidas, 1/2 taza de arroz integral, 100g de zanahoria, pimiento y comino.', 450, '{"p": 24, "c": 75, "f": 5}', null, 'lunch'),
('Pollo Teriyaki Saludable', '150g pollo, salsa teriyaki sin azúcar (stevia/soya), 1 taza brócoli, 1/2 taza arroz blanco.', 410, '{"p": 38, "c": 45, "f": 9}', null, 'lunch'),
('Albóndigas de Pavo al Curry', '150g pavo molido, salsa de tomate y curry, 150g calabaza al horno, 1/4 taza quinoa.', 390, '{"p": 34, "c": 35, "f": 12}', null, 'lunch'),
('Ensalada de Pasta y Garbanzo', '60g pasta integral, 1/2 taza garbanzos, tomates cherry, espinaca, aceitunas y vinagreta.', 470, '{"p": 18, "c": 68, "f": 14}', null, 'lunch'),
('Pescado Empapelado', '180g filete blanco, jitomate, cebolla y calabacita al vapor, 1 papa pequeña cocida.', 330, '{"p": 38, "c": 28, "f": 7}', null, 'lunch'),
('Fajitas de Res Magra', '120g bistec, pimientos tricolores, cebolla, 2 tortillas de maíz, salsa de chile de árbol.', 420, '{"p": 35, "c": 32, "f": 16}', null, 'lunch'),
('Atún con Ensalada Rusa Fit', '1 lata atún, papa y zanahoria cocidas (100g), chícharos, 1 cda mayonesa light, galletas habaneras.', 380, '{"p": 28, "c": 45, "f": 9}', null, 'lunch');

-- BLOQUE 2: CENAS
insert into default_meals (meal_title, meal_description, calories, macros, image_url, time_of_day) values
('Crema de Verduras y Pollo', '300ml crema calabacín y poro (sin lácteo), 100g pechuga pollo desmenuzada, crutones integrales.', 290, '{"p": 28, "c": 20, "f": 10}', null, 'dinner'),
('Hamburguesa de Pollo Sin Pan', '150g medallón pollo, envuelto en lechuga orejona, jitomate, cebolla, 1 rebanada queso bajo grasa.', 310, '{"p": 35, "c": 8, "f": 15}', null, 'dinner'),
('Pescado al Pesto', '150g filete blanco, 1 cda pesto albahaca, ensalada de arúgula y tomates deshidratados.', 340, '{"p": 32, "c": 10, "f": 20}', null, 'dinner'),
('Bowl Mediterráneo', '1/2 taza hummus, 1/4 taza pepino, 1/4 taza tomate, 5 aceitunas, 1 pan pita integral pequeño.', 360, '{"p": 12, "c": 48, "f": 14}', null, 'dinner'),
('Sopa de Lima Fitness', 'Caldo de pollo desgrasado, 100g pechuga pollo, tiras de tortilla horneadas (1 pza), cilantro y lima.', 270, '{"p": 26, "c": 24, "f": 6}', null, 'dinner'),
('Ceviche de Pescado', '200g pescado blanco en limón, cebolla, cilantro, chile serrano, pepino, 2 tostadas horneadas.', 280, '{"p": 38, "c": 25, "f": 3}', null, 'dinner'),
('Shakshuka Ligera', '2 huevos escalfados en salsa tomate y pimientos, 1/2 rebanada pan integral, especias árabes.', 310, '{"p": 18, "c": 22, "f": 16}', null, 'dinner');
