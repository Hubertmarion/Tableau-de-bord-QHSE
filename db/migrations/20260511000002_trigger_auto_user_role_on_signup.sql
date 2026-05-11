-- =====================================================================
-- Fix : trigger qui attribue automatiquement le rôle à la création
-- =====================================================================
-- Problème racine : l'upsert manuel dans GestionUtilisateurs.jsx
-- s'exécutait APRÈS que signUp() ait changé la session vers le nouvel
-- utilisateur. La policy RLS n'ayant pas de clause INSERT, l'upsert
-- était bloqué silencieusement → aucun rôle défini → timeout fetchRole.
--
-- Solution : trigger AFTER INSERT sur auth.users, SECURITY DEFINER,
-- qui lit le rôle depuis raw_user_meta_data et insère dans user_roles
-- de façon atomique — sans dépendre des permissions de session.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'lecteur');
  IF v_role NOT IN ('admin', 'lecteur', 'operateur', 'direction', 'responsable_qhse') THEN
    v_role := 'lecteur';
  END IF;

  INSERT INTO public.user_roles (user_id, role, email, nom)
  VALUES (
    NEW.id,
    v_role,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nom', '')
  )
  ON CONFLICT (user_id) DO UPDATE
    SET role = EXCLUDED.role,
        nom  = EXCLUDED.nom,
        updated_at = now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
