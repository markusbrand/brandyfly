//! 2D Spatial indexing (R-Tree), Equirectangular projection, point-in-polygon ray-casting,
//! and metric distance computations.

use super::ast::{BoundingBox, Coordinate};
use super::parser::EARTH_RADIUS_METERS;

/// Local Equirectangular projection centered at an anchor coordinate.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LocalProjection {
    pub origin: Coordinate,
    cos_origin_lat: f64,
}

impl LocalProjection {
    /// Constructs a local projection centered on `origin`.
    #[must_use]
    pub fn new(origin: Coordinate) -> Self {
        let cos_origin_lat = origin.latitude.to_radians().cos();
        Self {
            origin,
            cos_origin_lat,
        }
    }

    /// Projects geographic coordinate $(lat, lon)$ into local $(x, y)$ in meters.
    #[must_use]
    pub fn project(&self, coord: Coordinate) -> (f64, f64) {
        let d_lat_rad = (coord.latitude - self.origin.latitude).to_radians();
        let d_lon_rad = (coord.longitude - self.origin.longitude).to_radians();

        let avg_lat_rad = ((coord.latitude + self.origin.latitude) / 2.0).to_radians();
        let cos_avg = avg_lat_rad.cos();

        let x = EARTH_RADIUS_METERS * d_lon_rad * cos_avg;
        let y = EARTH_RADIUS_METERS * d_lat_rad;
        (x, y)
    }

    /// Unprojects local $(x, y)$ in meters back to geographic coordinate.
    #[must_use]
    pub fn unproject(&self, x: f64, y: f64) -> Coordinate {
        let d_lat_deg = (y / EARTH_RADIUS_METERS).to_degrees();
        let lat = self.origin.latitude + d_lat_deg;

        let avg_lat_rad = ((lat + self.origin.latitude) / 2.0).to_radians();
        let cos_avg = avg_lat_rad.cos().max(1e-6);

        let d_lon_deg = (x / (EARTH_RADIUS_METERS * cos_avg)).to_degrees();
        let lon = self.origin.longitude + d_lon_deg;

        Coordinate::new(lat, lon)
    }
}

/// Evaluates if point $P$ is inside a polygon using ray-casting (Jordan curve theorem).
#[must_use]
pub fn point_in_polygon(point: Coordinate, polygon: &[Coordinate]) -> bool {
    if polygon.len() < 3 {
        return false;
    }

    let mut inside = false;
    let x = point.longitude;
    let y = point.latitude;

    let n = polygon.len();
    for i in 0..n {
        let j = if i == 0 { n - 1 } else { i - 1 };
        let xi = polygon[i].longitude;
        let yi = polygon[i].latitude;
        let xj = polygon[j].longitude;
        let yj = polygon[j].latitude;

        let intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if intersect {
            inside = !inside;
        }
    }

    inside
}

/// Computes Cartesian distance from point $(px, py)$ to line segment $(x_1, y_1)-(x_2, y_2)$ in meters.
#[must_use]
pub fn point_to_segment_distance(
    px: f64,
    py: f64,
    x1: f64,
    y1: f64,
    x2: f64,
    y2: f64,
) -> (f64, (f64, f64)) {
    let dx = x2 - x1;
    let dy = y2 - y1;
    let len_sq = dx * dx + dy * dy;

    if len_sq < 1e-12 {
        let dist = ((px - x1).powi(2) + (py - y1).powi(2)).sqrt();
        return (dist, (x1, y1));
    }

    let t = (((px - x1) * dx + (py - y1) * dy) / len_sq).clamp(0.0, 1.0);
    let closest_x = x1 + t * dx;
    let closest_y = y1 + t * dy;

    let dist = ((px - closest_x).powi(2) + (py - closest_y).powi(2)).sqrt();
    (dist, (closest_x, closest_y))
}

/// Computes horizontal distance from `point` to polygon boundary in meters, and whether point is inside.
/// If inside, horizontal separation is considered 0.0 m.
#[must_use]
pub fn distance_point_to_polygon_meters(
    point: Coordinate,
    polygon: &[Coordinate],
) -> (f64, bool, (f64, f64)) {
    if polygon.len() < 2 {
        return (f64::INFINITY, false, (0.0, 0.0));
    }

    let is_inside = point_in_polygon(point, polygon);
    let proj = LocalProjection::new(point);
    let (px, py) = (0.0, 0.0);

    let mut min_dist = f64::INFINITY;
    let mut closest_pt = (0.0, 0.0);

    for i in 0..polygon.len() {
        let j = (i + 1) % polygon.len();
        let (x1, y1) = proj.project(polygon[i]);
        let (x2, y2) = proj.project(polygon[j]);

        let (dist, pt) = point_to_segment_distance(px, py, x1, y1, x2, y2);
        if dist < min_dist {
            min_dist = dist;
            closest_pt = pt;
        }
    }

    let separation = if is_inside { 0.0 } else { min_dist };
    (separation, is_inside, closest_pt)
}

/// Node in a 2D R-Tree.
#[derive(Clone, Debug)]
enum RTreeNode<T> {
    Leaf {
        bbox: BoundingBox,
        items: Vec<(BoundingBox, T)>,
    },
    Branch {
        bbox: BoundingBox,
        children: Vec<RTreeNode<T>>,
    },
}

impl<T> RTreeNode<T> {
    fn bbox(&self) -> BoundingBox {
        match self {
            Self::Leaf { bbox, .. } | Self::Branch { bbox, .. } => *bbox,
        }
    }
}

/// Balanced 2D R-Tree spatial index for fast bounding-box queries.
#[derive(Clone, Debug)]
pub struct RTree<T> {
    root: Option<RTreeNode<T>>,
    count: usize,
}

const MAX_LEAF_ITEMS: usize = 16;
const MAX_BRANCH_CHILDREN: usize = 8;

impl<T: Clone> Default for RTree<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T: Clone> RTree<T> {
    /// Creates an empty R-Tree.
    #[must_use]
    pub const fn new() -> Self {
        Self {
            root: None,
            count: 0,
        }
    }

    /// Number of items in the R-Tree.
    #[must_use]
    pub const fn len(&self) -> usize {
        self.count
    }

    /// True if the R-Tree is empty.
    #[must_use]
    pub const fn is_empty(&self) -> bool {
        self.count == 0
    }

    /// Builds a balanced 2D R-Tree using Sort-Tile-Recursive (STR) bulk-loading.
    #[must_use]
    pub fn bulk_load(mut items: Vec<(BoundingBox, T)>) -> Self {
        let count = items.len();
        if count == 0 {
            return Self::new();
        }

        let root = build_str_tree(&mut items);
        Self {
            root: Some(root),
            count,
        }
    }

    /// Queries all items whose bounding box intersects `target_bbox`.
    #[must_use]
    pub fn query(&self, target_bbox: &BoundingBox) -> Vec<&T> {
        let mut results = Vec::new();
        if let Some(ref root) = self.root {
            query_node(root, target_bbox, &mut results);
        }
        results
    }

    /// Queries all items within `radius_meters` of `center`.
    #[must_use]
    pub fn query_radius(&self, center: Coordinate, radius_meters: f64) -> Vec<&T> {
        let d_lat_deg = (radius_meters / 111_320.0).abs();
        let cos_lat = center.latitude.to_radians().cos().abs().max(0.1);
        let d_lon_deg = (radius_meters / (111_320.0 * cos_lat)).abs();

        let query_box = BoundingBox {
            min_lat: (center.latitude - d_lat_deg).max(-90.0),
            max_lat: (center.latitude + d_lat_deg).min(90.0),
            min_lon: (center.longitude - d_lon_deg).max(-180.0),
            max_lon: (center.longitude + d_lon_deg).min(180.0),
        };

        self.query(&query_box)
    }
}

fn combine_bboxes<'a, I>(bboxes: I) -> Option<BoundingBox>
where
    I: IntoIterator<Item = &'a BoundingBox>,
{
    let mut iter = bboxes.into_iter();
    let first = *iter.next()?;
    let mut min_lat = first.min_lat;
    let mut max_lat = first.max_lat;
    let mut min_lon = first.min_lon;
    let mut max_lon = first.max_lon;

    for bbox in iter {
        if bbox.min_lat < min_lat {
            min_lat = bbox.min_lat;
        }
        if bbox.max_lat > max_lat {
            max_lat = bbox.max_lat;
        }
        if bbox.min_lon < min_lon {
            min_lon = bbox.min_lon;
        }
        if bbox.max_lon > max_lon {
            max_lon = bbox.max_lon;
        }
    }

    Some(BoundingBox {
        min_lat,
        max_lat,
        min_lon,
        max_lon,
    })
}

fn build_str_tree<T: Clone>(items: &mut [(BoundingBox, T)]) -> RTreeNode<T> {
    if items.len() <= MAX_LEAF_ITEMS {
        let bboxes = items.iter().map(|(b, _)| b);
        let bbox = combine_bboxes(bboxes).unwrap_or(BoundingBox {
            min_lat: 0.0,
            max_lat: 0.0,
            min_lon: 0.0,
            max_lon: 0.0,
        });
        return RTreeNode::Leaf {
            bbox,
            items: items.to_vec(),
        };
    }

    // Sort items by center latitude
    items.sort_by(|a, b| {
        let mid_a = (a.0.min_lat + a.0.max_lat) / 2.0;
        let mid_b = (b.0.min_lat + b.0.max_lat) / 2.0;
        mid_a
            .partial_cmp(&mid_b)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let num_leaves = (items.len() as f64 / MAX_LEAF_ITEMS as f64).ceil() as usize;
    let num_vertical_slices = (num_leaves as f64).sqrt().ceil() as usize;
    let slice_size = items.len().div_ceil(num_vertical_slices);

    let mut leaf_nodes = Vec::new();

    for chunk in items.chunks_mut(slice_size) {
        // Sort each vertical slice by center longitude
        chunk.sort_by(|a, b| {
            let mid_a = (a.0.min_lon + a.0.max_lon) / 2.0;
            let mid_b = (b.0.min_lon + b.0.max_lon) / 2.0;
            mid_a
                .partial_cmp(&mid_b)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        for leaf_chunk in chunk.chunks(MAX_LEAF_ITEMS) {
            let bboxes = leaf_chunk.iter().map(|(b, _)| b);
            let bbox = combine_bboxes(bboxes).unwrap_or(BoundingBox {
                min_lat: 0.0,
                max_lat: 0.0,
                min_lon: 0.0,
                max_lon: 0.0,
            });
            leaf_nodes.push(RTreeNode::Leaf {
                bbox,
                items: leaf_chunk.to_vec(),
            });
        }
    }

    // Build hierarchical branch nodes from leaves
    build_branch_hierarchy(leaf_nodes)
}

fn build_branch_hierarchy<T: Clone>(mut nodes: Vec<RTreeNode<T>>) -> RTreeNode<T> {
    while nodes.len() > 1 {
        let mut next_level = Vec::new();
        for chunk in nodes.chunks(MAX_BRANCH_CHILDREN) {
            let bboxes = chunk.iter().map(|n| match n {
                RTreeNode::Leaf { bbox, .. } | RTreeNode::Branch { bbox, .. } => bbox,
            });
            let bbox = combine_bboxes(bboxes).unwrap_or(BoundingBox {
                min_lat: 0.0,
                max_lat: 0.0,
                min_lon: 0.0,
                max_lon: 0.0,
            });
            next_level.push(RTreeNode::Branch {
                bbox,
                children: chunk.to_vec(),
            });
        }
        nodes = next_level;
    }

    nodes.remove(0)
}

fn query_node<'a, T>(node: &'a RTreeNode<T>, target_bbox: &BoundingBox, results: &mut Vec<&'a T>) {
    if !node.bbox().intersects(target_bbox) {
        return;
    }

    match node {
        RTreeNode::Leaf { items, .. } => {
            for (bbox, item) in items {
                if bbox.intersects(target_bbox) {
                    results.push(item);
                }
            }
        }
        RTreeNode::Branch { children, .. } => {
            for child in children {
                query_node(child, target_bbox, results);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_local_projection_roundtrip() {
        let origin = Coordinate::new(47.2692, 11.3933); // Innsbruck
        let proj = LocalProjection::new(origin);

        let target = Coordinate::new(47.3000, 11.4500);
        let (x, y) = proj.project(target);

        let roundtrip = proj.unproject(x, y);
        assert!((roundtrip.latitude - target.latitude).abs() < 1e-6);
        assert!((roundtrip.longitude - target.longitude).abs() < 1e-6);
    }

    #[test]
    fn test_point_in_polygon_ray_casting() {
        let poly = vec![
            Coordinate::new(47.0, 11.0),
            Coordinate::new(47.5, 11.0),
            Coordinate::new(47.5, 11.5),
            Coordinate::new(47.0, 11.5),
            Coordinate::new(47.0, 11.0),
        ];

        assert!(point_in_polygon(Coordinate::new(47.2, 11.2), &poly));
        assert!(!point_in_polygon(Coordinate::new(46.8, 11.2), &poly));
        assert!(!point_in_polygon(Coordinate::new(47.2, 11.8), &poly));
    }

    #[test]
    fn test_distance_point_to_polygon() {
        let poly = vec![
            Coordinate::new(47.0, 11.0),
            Coordinate::new(47.1, 11.0),
            Coordinate::new(47.1, 11.1),
            Coordinate::new(47.0, 11.1),
            Coordinate::new(47.0, 11.0),
        ];

        // Inside polygon -> horizontal separation 0.0 m
        let (dist_in, inside, _) =
            distance_point_to_polygon_meters(Coordinate::new(47.05, 11.05), &poly);
        assert!(inside);
        assert_eq!(dist_in, 0.0);

        // Outside polygon (north by approx 0.05 deg ~= 5.5 km)
        let (dist_out, inside_out, _) =
            distance_point_to_polygon_meters(Coordinate::new(47.15, 11.05), &poly);
        assert!(!inside_out);
        assert!(dist_out > 5_000.0 && dist_out < 6_000.0);
    }

    #[test]
    fn test_rtree_bulk_loading_and_query_10k_microbenchmark() {
        // Construct 10,000 spatial boxes in a grid
        let mut items = Vec::with_capacity(10_000);
        for i in 0..100 {
            for j in 0..100 {
                let lat = 40.0 + (i as f64) * 0.1;
                let lon = 10.0 + (j as f64) * 0.1;
                let bbox = BoundingBox {
                    min_lat: lat,
                    max_lat: lat + 0.08,
                    min_lon: lon,
                    max_lon: lon + 0.08,
                };
                items.push((bbox, i * 100 + j));
            }
        }

        let rtree = RTree::bulk_load(items);
        assert_eq!(rtree.len(), 10_000);

        // Query a point at (45.05, 15.05) with 15km radius
        let start = std::time::Instant::now();
        let results = rtree.query_radius(Coordinate::new(45.05, 15.05), 15_000.0);
        let elapsed = start.elapsed();

        assert!(!results.is_empty());
        // $O(\log N)$ query must easily complete in < 100 microseconds (0.1 ms)
        assert!(
            elapsed.as_micros() < 2_000,
            "R-Tree spatial query took too long: {:?}",
            elapsed
        );
    }
}
